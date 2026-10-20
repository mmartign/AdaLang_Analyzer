--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Slocs;
with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;    use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.SPARK_Readiness;
with Adalang_Analyzer.Subprogram_Summaries;
with Adalang_Analyzer.Termination;
with Adalang_Analyzer.Text_Utils;  use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Flow_Contracts is

   package Proof renames Adalang_Analyzer.Proof_Obligations;

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;

   --  How a subprogram uses an object declared outside it, the stronger
   --  use standing for the weaker: a write is to be allowed as a write
   --  whether or not the object is read as well.
   type Access_Kind is (Proof_Read, Read, Write);

   type Object_Access is record
      Kind : Access_Kind := Proof_Read;
      Site : Libadalang.Analysis.Defining_Name :=
        Libadalang.Analysis.No_Defining_Name;
   end record;

   package Access_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Object_Access,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  What a subprogram may touch. Complete is False as soon as something
   --  it does could not be followed; Objects is then a lower bound only
   --  and proves nothing.
   type Effects is record
      Complete : Boolean := True;
      Reason   : Unbounded_String;
      Objects  : Access_Maps.Map;
   end record;

   type Effects_State is (In_Progress, Done);

   type Known_Effects is record
      State : Effects_State := In_Progress;
      Value : Effects;
   end record;

   package Effects_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Known_Effects,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Known : Effects_Maps.Map;

   procedure Clear_Flow_Dependencies;

   procedure Reset is
   begin
      Known.Clear;
      Clear_Flow_Dependencies;
   end Reset;

   function Text_Of
     (Text : Langkit_Support.Text.Text_Type) return String
   is (Langkit_Support.Text.To_UTF8 (Text));

   --  Where Name is written: what tells two objects apart.
   function Key_Of
     (Name : Libadalang.Analysis.Defining_Name'Class) return String
   is (Name.Unit.Get_Filename & ":" &
       Langkit_Support.Slocs.Image
         (Langkit_Support.Slocs.Start_Sloc (Name.Sloc_Range)));

   function Lower_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String
   is (Normalize_Rule_Name (Node_Text (Node)));

   procedure Give_Up (Into : in out Effects; Reason : String) is
   begin
      if Into.Complete then
         Into.Complete := False;
         Into.Reason := To_Unbounded_String (Reason);
      end if;
   end Give_Up;

   function Is_Inside
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Scope : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Node.As_Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Scope) then
         return False;
      end if;
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current = Scope.As_Ada_Node then
            return True;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_Inside;

   function Aspect_Expression
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Libadalang.Analysis.Expr
   is (Decl.P_Get_Aspect_Spec_Expr
         (Langkit_Support.Text.To_Unbounded_Text
            (Langkit_Support.Text.To_Text (Name))));

   --  The declaration a caller sees of Subprogram when it is not
   --  Subprogram itself; null otherwise.
   function Earlier_Declaration
     (Subprogram : Libadalang.Analysis.Basic_Decl'Class)
      return Libadalang.Analysis.Basic_Decl
   is
      First : constant Libadalang.Analysis.Basic_Decl :=
        Subprogram.P_Canonical_Part;
   begin
      if Libadalang.Analysis.Is_Null (First)
        or else First.As_Ada_Node = Subprogram.As_Ada_Node
      then
         return Libadalang.Analysis.No_Basic_Decl;
      end if;
      return First;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Earlier_Declaration;

   --  The aspect Name of a subprogram, on its body or on its declaration.
   function Contract
     (Subprogram : Libadalang.Analysis.Basic_Decl'Class;
      Name       : String) return Libadalang.Analysis.Expr
   is
      Result : Libadalang.Analysis.Expr :=
        Aspect_Expression (Subprogram, Name);
   begin
      if Libadalang.Analysis.Is_Null (Result) then
         declare
            First : constant Libadalang.Analysis.Basic_Decl :=
              Earlier_Declaration (Subprogram);
         begin
            if not Libadalang.Analysis.Is_Null (First) then
               Result := Aspect_Expression (First, Name);
            end if;
         end;
      end if;
      return Result;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Contract;

   ------------------------------------------------------------------
   --  Constants
   ------------------------------------------------------------------

   --  The declaration that gives a deferred constant its value; Decl
   --  itself otherwise.
   function Completed (Decl : Libadalang.Analysis.Object_Decl)
     return Libadalang.Analysis.Object_Decl is
   begin
      if Decl.F_Has_Constant.Kind = Libadalang.Common.Ada_Constant_Present
        and then Libadalang.Analysis.Is_Null (Decl.F_Renaming_Clause)
        and then Libadalang.Analysis.Is_Null (Decl.F_Default_Expr)
      then
         declare
            Next : constant Libadalang.Analysis.Basic_Decl :=
              Decl.P_Next_Part_For_Decl;
         begin
            if not Libadalang.Analysis.Is_Null (Next)
              and then Next.Kind = Libadalang.Common.Ada_Object_Decl
            then
               return Next.As_Object_Decl;
            end if;
         end;
      end if;
      return Decl;
   exception
      when others =>
         return Decl;
   end Completed;

   --  True when the value of Expr does not depend on a variable: it is
   --  built from literals, types, named numbers, enumeration literals,
   --  predefined operations and constants of which the same is true. A
   --  constant initialized that way is not a global of anything.
   function Is_Variable_Free
     (Expr  : Libadalang.Analysis.Ada_Node'Class;
      Depth : Natural := 0) return Boolean
   is
      Max_Depth : constant := 6;
   begin
      if Libadalang.Analysis.Is_Null (Expr) then
         return True;
      elsif Depth > Max_Depth then
         return False;
      end if;

      case Expr.Kind is
         when Libadalang.Common.Ada_Identifier =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Expr.As_Name.P_Referenced_Decl;
            begin
               if Libadalang.Analysis.Is_Null (Decl) then
                  return False;
               end if;

               case Decl.Kind is
                  when Libadalang.Common.Ada_Base_Type_Decl
                     | Libadalang.Common.Ada_Number_Decl
                     | Libadalang.Common.Ada_Enum_Literal_Decl
                     | Libadalang.Common.Ada_Component_Decl
                     | Libadalang.Common.Ada_Discriminant_Spec
                     | Libadalang.Common.Ada_Package_Decl
                     | Libadalang.Common.Ada_Package_Body
                     | Libadalang.Common.Ada_Package_Renaming_Decl
                     | Libadalang.Common.Ada_Synthetic_Subp_Decl =>
                     return True;
                  when Libadalang.Common.Ada_Anonymous_Expr_Decl =>
                     --  A generic formal object seen from an instance: the
                     --  actual of the instantiation.
                     return Is_Variable_Free
                         (Decl.As_Anonymous_Expr_Decl.F_Expr, Depth + 1);
                  when Libadalang.Common.Ada_Object_Decl =>
                     if not Libadalang.Analysis.Is_Null (Decl.Parent)
                       and then Decl.Parent.Kind =
                         Libadalang.Common.Ada_Generic_Formal_Obj_Decl
                     then
                        --  A generic formal object of mode in.
                        return Libadalang.Analysis.Is_Null
                            (Decl.As_Object_Decl.F_Mode)
                          or else Decl.As_Object_Decl.F_Mode.Kind in
                            Libadalang.Common.Ada_Mode_Default
                              | Libadalang.Common.Ada_Mode_In;
                     end if;
                     declare
                        Full : constant Libadalang.Analysis.Object_Decl :=
                          Completed (Decl.As_Object_Decl);
                     begin
                        return Full.F_Has_Constant.Kind =
                            Libadalang.Common.Ada_Constant_Present
                          and then Libadalang.Analysis.Is_Null
                                     (Full.F_Renaming_Clause)
                          and then not Libadalang.Analysis.Is_Null
                                         (Full.F_Default_Expr)
                          and then Is_Variable_Free
                                     (Full.F_Default_Expr, Depth + 1);
                     end;
                  when others =>
                     return False;
               end case;
            end;

         when Libadalang.Common.Ada_Attribute_Ref =>
            --  The attribute designator names nothing.
            return Is_Variable_Free
                (Expr.As_Attribute_Ref.F_Prefix, Depth)
              and then Is_Variable_Free
                         (Expr.As_Attribute_Ref.F_Args, Depth);

         when Libadalang.Common.Ada_Explicit_Deref
            | Libadalang.Common.Ada_Allocator =>
            return False;

         when others =>
            for Index in 1 .. Expr.Children_Count loop
               if not Is_Variable_Free (Expr.Child (Index), Depth) then
                  return False;
               end if;
            end loop;
            return True;
      end case;
   exception
      when others =>
         return False;
   end Is_Variable_Free;

   function Is_Static (Expr : Libadalang.Analysis.Expr) return Boolean is
   begin
      return Expr.P_Is_Static_Expr;
   exception
      when others =>
         return False;
   end Is_Static;

   --  True when the object Name declares is not a global of any
   --  subprogram: a constant whose value depends on no variable, or a
   --  generic formal object of mode in.
   function Is_Not_A_Global
     (Name : Libadalang.Analysis.Defining_Name'Class) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl := Name.P_Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind /= Libadalang.Common.Ada_Object_Decl
      then
         return False;
      end if;

      declare
         Object : constant Libadalang.Analysis.Object_Decl :=
           Completed (Decl.As_Object_Decl);
      begin
         if not Libadalang.Analysis.Is_Null (Object.Parent)
           and then Object.Parent.Kind =
             Libadalang.Common.Ada_Generic_Formal_Obj_Decl
         then
            return Libadalang.Analysis.Is_Null (Object.F_Mode)
              or else Object.F_Mode.Kind in
                Libadalang.Common.Ada_Mode_Default
                  | Libadalang.Common.Ada_Mode_In;
         end if;

         return Object.F_Has_Constant.Kind =
             Libadalang.Common.Ada_Constant_Present
           and then Libadalang.Analysis.Is_Null (Object.F_Renaming_Clause)
           and then not Libadalang.Analysis.Is_Null (Object.F_Default_Expr)
           and then
             (Is_Static (Object.F_Default_Expr)
              or else Is_Variable_Free (Object.F_Default_Expr));
      end;
   exception
      when others =>
         return False;
   end Is_Not_A_Global;

   ------------------------------------------------------------------
   --  Objects
   ------------------------------------------------------------------

   --  The object Node is, or is a part of, or designates: the root of a
   --  name, behind any renaming. Null when Node is not such a name.
   function Object_Of
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Depth : Natural := 0) return Libadalang.Analysis.Defining_Name
   is
      Max_Depth : constant := 16;
      None      : Libadalang.Analysis.Defining_Name renames
        Libadalang.Analysis.No_Defining_Name;
   begin
      if Libadalang.Analysis.Is_Null (Node) or else Depth > Max_Depth then
         return None;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Identifier
            | Libadalang.Common.Ada_Dotted_Name =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Node.As_Name.P_Referenced_Decl;
            begin
               if Libadalang.Analysis.Is_Null (Decl) then
                  return None;
               end if;

               case Decl.Kind is
                  when Libadalang.Common.Ada_Object_Decl
                     | Libadalang.Common
                         .Ada_Extended_Return_Stmt_Object_Decl =>
                     if not Libadalang.Analysis.Is_Null
                              (Decl.As_Object_Decl.F_Renaming_Clause)
                     then
                        return Object_Of
                          (Decl.As_Object_Decl.F_Renaming_Clause
                             .F_Renamed_Object,
                           Depth + 1);
                     end if;
                     return Node.As_Name.P_Referenced_Defining_Name;

                  when Libadalang.Common.Ada_Param_Spec
                     | Libadalang.Common.Ada_For_Loop_Var_Decl =>
                     return Node.As_Name.P_Referenced_Defining_Name;

                  when Libadalang.Common.Ada_Component_Decl
                     | Libadalang.Common.Ada_Discriminant_Spec =>
                     --  A selected component: the object is the prefix.
                     if Node.Kind = Libadalang.Common.Ada_Dotted_Name then
                        return Object_Of
                          (Node.As_Dotted_Name.F_Prefix, Depth + 1);
                     end if;
                     return None;

                  when others =>
                     return None;
               end case;
            end;

         when Libadalang.Common.Ada_Call_Expr =>
            case Node.As_Call_Expr.P_Kind is
               when Libadalang.Common.Array_Index
                  | Libadalang.Common.Array_Slice =>
                  return Object_Of (Node.As_Call_Expr.F_Name, Depth + 1);
               when Libadalang.Common.Type_Conversion =>
                  declare
                     Suffix : constant Libadalang.Analysis.Ada_Node :=
                       Node.As_Call_Expr.F_Suffix;
                  begin
                     if Suffix.Kind in Libadalang.Common.Ada_Expr then
                        return Object_Of (Suffix, Depth + 1);
                     elsif Suffix.Children_Count = 1
                       and then Suffix.Child (1).Kind =
                         Libadalang.Common.Ada_Param_Assoc
                     then
                        return Object_Of
                          (Suffix.Child (1).As_Param_Assoc.F_R_Expr,
                           Depth + 1);
                     end if;
                     return None;
                  end;
               when others =>
                  return None;
            end case;

         when Libadalang.Common.Ada_Explicit_Deref =>
            return Object_Of (Node.As_Explicit_Deref.F_Prefix, Depth + 1);

         when Libadalang.Common.Ada_Paren_Expr =>
            return Object_Of (Node.As_Paren_Expr.F_Expr, Depth + 1);

         when others =>
            return None;
      end case;
   exception
      when others =>
         return Libadalang.Analysis.No_Defining_Name;
   end Object_Of;

   ------------------------------------------------------------------
   --  Global aspects
   ------------------------------------------------------------------

   type Global_Mode is (Input, Output, In_Out, Proof_In);

   type Global_Item is record
      Mode : Global_Mode := Input;
      Site : Libadalang.Analysis.Defining_Name :=
        Libadalang.Analysis.No_Defining_Name;
   end record;

   package Item_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Global_Item,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Global_Contract is record
      Resolved : Boolean := True;
      Items    : Item_Maps.Map;
   end record;

   --  What a Global or Refined_Global aspect lists. Resolved is False when
   --  one of its names could not be told.
   function Parse_Global
     (Expr : Libadalang.Analysis.Expr'Class) return Global_Contract
   is
      Result : Global_Contract;

      procedure Add_Items
        (Node : Libadalang.Analysis.Ada_Node'Class; Mode : Global_Mode) is
      begin
         if Libadalang.Analysis.Is_Null (Node)
           or else Node.Kind = Libadalang.Common.Ada_Null_Literal
         then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
            Add_Items (Node.As_Paren_Expr.F_Expr, Mode);
         elsif Node.Kind in Libadalang.Common.Ada_Base_Aggregate then
            for Item of Node.As_Base_Aggregate.F_Assocs loop
               if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc
                 and then Item.As_Aggregate_Assoc.F_Designators
                            .Children_Count = 0
               then
                  Add_Items (Item.As_Aggregate_Assoc.F_R_Expr, Mode);
               else
                  Result.Resolved := False;
               end if;
            end loop;
         elsif Node.Kind in Libadalang.Common.Ada_Identifier
                 | Libadalang.Common.Ada_Dotted_Name
         then
            declare
               Site : constant Libadalang.Analysis.Defining_Name :=
                 Node.As_Name.P_Referenced_Defining_Name;
            begin
               if Libadalang.Analysis.Is_Null (Site) then
                  Result.Resolved := False;
               else
                  Result.Items.Include
                    (Key_Of (Site), (Mode => Mode, Site => Site));
               end if;
            end;
         else
            Result.Resolved := False;
         end if;
      end Add_Items;
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind = Libadalang.Common.Ada_Null_Literal
      then
         return Result;
      elsif Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate then
         Add_Items (Expr, Input);
         return Result;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind /= Libadalang.Common.Ada_Aggregate_Assoc then
            Result.Resolved := False;
         else
            declare
               Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                 Item.As_Aggregate_Assoc;
               Mode  : constant String :=
                 (if Assoc.F_Designators.Children_Count = 0 then "input"
                  else Lower_Text (Assoc.F_Designators.Child (1)));
            begin
               if Mode = "input" then
                  Add_Items (Assoc.F_R_Expr, Input);
               elsif Mode = "output" then
                  Add_Items (Assoc.F_R_Expr, Output);
               elsif Mode = "in-out" then
                  Add_Items (Assoc.F_R_Expr, In_Out);
               elsif Mode = "proof-in" then
                  Add_Items (Assoc.F_R_Expr, Proof_In);
               else
                  Result.Resolved := False;
               end if;
            end;
         end if;
      end loop;
      return Result;
   exception
      when others =>
         Result.Resolved := False;
         return Result;
   end Parse_Global;

   --  The state abstraction Object is a constituent of, by its own Part_Of
   --  or by the Refined_State of a package body that From is in. Null when
   --  it is a constituent of none.
   function Encapsulating_State
     (Object : Libadalang.Analysis.Defining_Name'Class;
      From   : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Defining_Name
   is
      None : Libadalang.Analysis.Defining_Name renames
        Libadalang.Analysis.No_Defining_Name;
      Decl : constant Libadalang.Analysis.Basic_Decl := Object.P_Basic_Decl;

      function Names
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif Node.Kind in Libadalang.Common.Ada_Identifier
                 | Libadalang.Common.Ada_Dotted_Name
         then
            declare
               Site : constant Libadalang.Analysis.Defining_Name :=
                 Node.As_Name.P_Referenced_Defining_Name;
            begin
               return not Libadalang.Analysis.Is_Null (Site)
                 and then Key_Of (Site) = Key_Of (Object);
            end;
         end if;
         for Index in 1 .. Node.Children_Count loop
            if Names (Node.Child (Index)) then
               return True;
            end if;
         end loop;
         return False;
      end Names;
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return None;
      end if;

      declare
         Part_Of : constant Libadalang.Analysis.Expr :=
           Aspect_Expression (Decl, "Part_Of");
      begin
         if not Libadalang.Analysis.Is_Null (Part_Of)
           and then Part_Of.Kind in Libadalang.Common.Ada_Name
         then
            return Part_Of.As_Name.P_Referenced_Defining_Name;
         end if;
      end;

      declare
         Ancestor : Libadalang.Analysis.Ada_Node := From.Parent;
      begin
         while not Libadalang.Analysis.Is_Null (Ancestor) loop
            if Ancestor.Kind = Libadalang.Common.Ada_Package_Body then
               declare
                  Refined : constant Libadalang.Analysis.Expr :=
                    Aspect_Expression
                      (Ancestor.As_Basic_Decl, "Refined_State");
               begin
                  if not Libadalang.Analysis.Is_Null (Refined)
                    and then Refined.Kind in
                      Libadalang.Common.Ada_Base_Aggregate
                  then
                     for Item of Refined.As_Base_Aggregate.F_Assocs loop
                        if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc
                          and then Item.As_Aggregate_Assoc.F_Designators
                                     .Children_Count = 1
                          and then Names (Item.As_Aggregate_Assoc.F_R_Expr)
                        then
                           return Item.As_Aggregate_Assoc.F_Designators
                             .Child (1).As_Name.P_Referenced_Defining_Name;
                        end if;
                     end loop;
                  end if;
               end;
            end if;
            Ancestor := Ancestor.Parent;
         end loop;
      end;
      return None;
   exception
      when others =>
         return Libadalang.Analysis.No_Defining_Name;
   end Encapsulating_State;

   ------------------------------------------------------------------
   --  Effects
   ------------------------------------------------------------------

   procedure Note
     (Into   : in out Effects;
      Object : Libadalang.Analysis.Defining_Name'Class;
      Kind   : Access_Kind)
   is
   begin
      if Libadalang.Analysis.Is_Null (Object) then
         return;
      end if;

      declare
         Key : constant String := Key_Of (Object);
      begin
         if Into.Objects.Contains (Key) then
            if Kind > Into.Objects.Element (Key).Kind then
               Into.Objects.Replace
                 (Key, (Kind => Kind, Site => Object.As_Defining_Name));
            end if;
         else
            Into.Objects.Insert
              (Key, (Kind => Kind, Site => Object.As_Defining_Name));
         end if;
      end;
   end Note;

   function Body_Effects
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class) return Effects;

   --  The aspect Name of the generic subprogram Instance is an instance of;
   --  null when it has none.
   function Generic_Contract
     (Instance : Libadalang.Analysis.Basic_Decl'Class;
      Name     : String) return Libadalang.Analysis.Expr
   is
      Generic_Decl : constant Libadalang.Analysis.Basic_Decl :=
        Instance.As_Generic_Subp_Instantiation.P_Designated_Generic_Decl
          .As_Basic_Decl;
      Result       : Libadalang.Analysis.Expr;
   begin
      if Libadalang.Analysis.Is_Null (Generic_Decl)
        or else Generic_Decl.Kind /= Libadalang.Common.Ada_Generic_Subp_Decl
      then
         return Libadalang.Analysis.No_Expr;
      end if;
      Result := Contract (Generic_Decl, Name);
      if Libadalang.Analysis.Is_Null (Result) then
         Result := Contract
           (Generic_Decl.As_Generic_Subp_Decl.F_Subp_Decl, Name);
      end if;
      return Result;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Generic_Contract;

   function Actuals_Keep_To_Themselves
     (Formal : Libadalang.Analysis.Basic_Decl'Class;
      Depth  : Natural) return Boolean;

   --  True when Decl is declared in a pure unit, which has no state.
   function Is_Pure_Unit
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Unit_Decl : constant Libadalang.Analysis.Basic_Decl :=
        Decl.P_Enclosing_Compilation_Unit.P_Decl;
   begin
      return not Libadalang.Analysis.Is_Null
                   (Aspect_Expression (Unit_Decl, "Pure"))
        or else Libadalang.Analysis.Exists
                  (Unit_Decl.P_Get_Aspect
                     (Langkit_Support.Text.To_Unbounded_Text
                        (Langkit_Support.Text.To_Text ("Pure"))));
   exception
      when others =>
         return False;
   end Is_Pure_Unit;

   --  What a call to Decl may touch: what its Global aspect says, or what
   --  its body shows when it has none.
   function Callee_Effects
     (Decl   : Libadalang.Analysis.Basic_Decl'Class;
      Caller : Libadalang.Analysis.Ada_Node'Class;
      Depth  : Natural := 0) return Effects
   is
      Max_Renamings : constant := 8;
      Result        : Effects;
      Name          : constant String :=
        (if Libadalang.Analysis.Is_Null (Decl) then "a subprogram"
         else Node_Text (Decl.P_Defining_Name));

      procedure From_Contract (Global : Libadalang.Analysis.Expr'Class) is
         Listed : constant Global_Contract := Parse_Global (Global);
      begin
         if not Listed.Resolved then
            Give_Up
              (Result, "the Global aspect of " & Name & " was not resolved");
         end if;
         for Item of Listed.Items loop
            Note
              (Result, Item.Site,
               (case Item.Mode is
                   when Input => Read,
                   when Proof_In => Proof_Read,
                   when Output | In_Out => Write));
         end loop;
      end From_Contract;

      procedure From_Body (Next : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Next) then
            Give_Up
              (Result,
               Name & " has no Global aspect and no body to look at");
            return;
         elsif Next.Kind = Libadalang.Common.Ada_Null_Subp_Decl then
            --  A null procedure touches nothing.
            return;
         end if;

         case Next.Kind is
            when Libadalang.Common.Ada_Subp_Body
               | Libadalang.Common.Ada_Expr_Function =>
               --  Where the body is visible from the caller its refined
               --  contract says more than the declaration's does.
               declare
                  Refined : constant Libadalang.Analysis.Expr :=
                    Aspect_Expression
                      (Next.As_Basic_Decl, "Refined_Global");
               begin
                  if not Libadalang.Analysis.Is_Null (Refined) then
                     From_Contract (Refined);
                  else
                     Result := Body_Effects (Next.As_Base_Subp_Body);
                  end if;
               end;
            when Libadalang.Common.Ada_Subp_Renaming_Decl
               | Libadalang.Common.Ada_Subp_Body_Stub =>
               Result :=
                 Callee_Effects (Next.As_Basic_Decl, Caller, Depth + 1);
            when others =>
               Give_Up
                 (Result,
                  Name & " has no Global aspect and no body to look at");
         end case;
      end From_Body;
   begin
      if Libadalang.Analysis.Is_Null (Decl) or else Depth > Max_Renamings
      then
         Give_Up (Result, "a call was not resolved");
         return Result;
      end if;

      case Decl.Kind is
         when Libadalang.Common.Ada_Enum_Literal_Decl
            | Libadalang.Common.Ada_Synthetic_Subp_Decl
            | Libadalang.Common.Ada_Null_Subp_Decl =>
            return Result;

         when Libadalang.Common.Ada_Subp_Decl
            | Libadalang.Common.Ada_Generic_Subp_Internal
            | Libadalang.Common.Ada_Subp_Body
            | Libadalang.Common.Ada_Expr_Function
            | Libadalang.Common.Ada_Subp_Body_Stub
            | Libadalang.Common.Ada_Formal_Subp_Decl =>
            declare
               Global  : constant Libadalang.Analysis.Expr :=
                 Contract (Decl, "Global");
               Next    : constant Libadalang.Analysis.Ada_Node :=
                 (if Decl.Kind in Libadalang.Common.Ada_Subp_Body
                       | Libadalang.Common.Ada_Expr_Function
                  then Decl.As_Ada_Node
                  elsif Decl.Kind in Libadalang.Common.Ada_Formal_Subp_Decl
                  then Libadalang.Analysis.No_Ada_Node
                  elsif Decl.Kind = Libadalang.Common.Ada_Subp_Body_Stub
                  then Decl.P_Next_Part_For_Decl.As_Ada_Node
                  else Decl.P_Body_Part_For_Decl.As_Ada_Node);
               Refined : constant Libadalang.Analysis.Expr :=
                 (if not Libadalang.Analysis.Is_Null (Next)
                    and then Next.Kind in Libadalang.Common.Ada_Subp_Body
                      | Libadalang.Common.Ada_Expr_Function
                  then Aspect_Expression
                         (Next.As_Basic_Decl, "Refined_Global")
                  else Libadalang.Analysis.No_Expr);

               --  The refinement is the caller's business only inside the
               --  package body that holds the callee's body.
               function Refinement_Visible return Boolean is
                  Scope : Libadalang.Analysis.Ada_Node := Next.Parent;
               begin
                  while not Libadalang.Analysis.Is_Null (Scope) loop
                     if Scope.Kind = Libadalang.Common.Ada_Package_Body then
                        return Is_Inside (Caller, Scope);
                     end if;
                     Scope := Scope.Parent;
                  end loop;
                  return False;
               end Refinement_Visible;
            begin
               if not Libadalang.Analysis.Is_Null (Refined)
                 and then Refinement_Visible
               then
                  From_Contract (Refined);
               elsif not Libadalang.Analysis.Is_Null (Global) then
                  From_Contract (Global);
               elsif Decl.Kind in Libadalang.Common.Ada_Formal_Subp_Decl
               then
                  if not Actuals_Keep_To_Themselves (Decl, 0) then
                     Give_Up
                       (Result,
                        Name & " is a generic formal subprogram with no " &
                        "Global aspect");
                  end if;
               elsif Is_Pure_Unit (Decl) then
                  --  A subprogram of a pure unit has no state to touch.
                  return Result;
               elsif Termination.Is_Library_Unit_Entity (Decl) then
                  Give_Up
                    (Result,
                     Name & " is a library subprogram with no Global " &
                     "aspect");
               elsif Decl.P_Is_Imported then
                  --  An intrinsic has no state; anything else that is
                  --  imported may have any.
                  declare
                     Convention : constant Libadalang.Analysis.Expr :=
                       Aspect_Expression (Decl, "Convention");
                  begin
                     if Libadalang.Analysis.Is_Null (Convention)
                       or else Lower_Text (Convention) /= "intrinsic"
                     then
                        Give_Up
                          (Result,
                           Name & " is imported and has no Global aspect");
                     end if;
                  end;
               else
                  From_Body (Next);
               end if;
               return Result;
            end;

         when Libadalang.Common.Ada_Subp_Renaming_Decl =>
            declare
               Renamed : constant Libadalang.Analysis.Name :=
                 Decl.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object;
            begin
               if Renamed.Kind = Libadalang.Common.Ada_Attribute_Ref then
                  return Result;
               end if;
               return Callee_Effects
                 (Renamed.P_Referenced_Decl, Caller, Depth + 1);
            end;

         when Libadalang.Common.Ada_Generic_Subp_Instantiation =>
            declare
               Generic_Name : constant String :=
                 Normalize_Rule_Name
                   (Text_Of
                      (Decl.As_Generic_Subp_Instantiation
                         .F_Generic_Subp_Name.P_Referenced_Decl
                         .P_Fully_Qualified_Name));
            begin
               if Generic_Name not in "ada.unchecked-conversion"
                    | "ada.unchecked-deallocation"
                    | "unchecked-conversion"
                    | "unchecked-deallocation"
               then
                  declare
                     Global : constant Libadalang.Analysis.Expr :=
                       Generic_Contract (Decl, "Global");
                  begin
                     if Libadalang.Analysis.Is_Null (Global) then
                        Give_Up
                          (Result,
                           "the effects of the generic instance " & Name &
                           " are not followed");
                     else
                        From_Contract (Global);
                     end if;
                  end;
               end if;
               return Result;
            end;

         when others =>
            Give_Up
              (Result,
               "the effects of the call to " & Name & " are not known");
            return Result;
      end case;
   exception
      when Exc : others =>
         Give_Up
           (Result,
            "the call to " & Name & " was not resolved: " &
            Ada.Exceptions.Exception_Message (Exc));
         return Result;
   end Callee_Effects;

   --  Adds to Into what Node and all under it may touch that is declared
   --  outside Subprogram.
   procedure Scan
     (Node         : Libadalang.Analysis.Ada_Node'Class;
      Subprogram   : Libadalang.Analysis.Base_Subp_Body'Class;
      Declaration  : Libadalang.Analysis.Basic_Decl'Class;
      In_Assertion : Boolean;
      Into         : in out Effects)
   is
      function Is_Local
        (Object : Libadalang.Analysis.Defining_Name'Class) return Boolean
      is (Is_Inside (Object, Subprogram)
          or else Is_Inside (Object, Declaration));

      procedure Use_Object
        (Object : Libadalang.Analysis.Defining_Name'Class;
         Kind   : Access_Kind) is
      begin
         if not Libadalang.Analysis.Is_Null (Object)
           and then not Is_Local (Object)
           and then not Is_Not_A_Global (Object)
         then
            Note (Into, Object, Kind);
         end if;
      end Use_Object;

      procedure Scan_Children (As_Assertion : Boolean := In_Assertion) is
      begin
         for Index in 1 .. Node.Children_Count loop
            Scan
              (Node.Child (Index), Subprogram, Declaration, As_Assertion,
               Into);
         end loop;
      end Scan_Children;

      --  The variable a statement or a call stores into.
      procedure Write_To (Target : Libadalang.Analysis.Ada_Node'Class) is
         Object : constant Libadalang.Analysis.Defining_Name :=
           Object_Of (Target);
      begin
         if Libadalang.Analysis.Is_Null (Object) then
            Give_Up
              (Into,
               "what " & Node_Text (Target) & " stores into was not told");
         else
            Use_Object (Object, Write);
         end if;
      end Write_To;

      procedure Use_Callee (Decl : Libadalang.Analysis.Basic_Decl'Class) is
         Callee : constant Effects := Callee_Effects (Decl, Subprogram);
      begin
         if not Callee.Complete then
            Give_Up (Into, To_String (Callee.Reason));
         end if;
         for Item of Callee.Objects loop
            Use_Object
              (Item.Site,
               (if In_Assertion then Proof_Read else Item.Kind));
         end loop;
      end Use_Callee;

      --  A name that denotes a subprogram is a call to it, or hands it to
      --  something that may call it.
      procedure Use_Name (Name : Libadalang.Analysis.Name'Class) is
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Decl) then
            return;
         end if;

         case Decl.Kind is
            when Libadalang.Common.Ada_Basic_Subp_Decl
               | Libadalang.Common.Ada_Base_Subp_Body
               | Libadalang.Common.Ada_Subp_Body_Stub
               | Libadalang.Common.Ada_Generic_Subp_Instantiation =>
               if Name.P_Is_Dispatching_Call then
                  Give_Up
                    (Into,
                     "the call to " & Node_Text (Name) & " dispatches");
               else
                  Use_Callee (Decl);
               end if;

            when Libadalang.Common.Ada_Single_Protected_Decl
               | Libadalang.Common.Ada_Single_Task_Decl
               | Libadalang.Common.Ada_Protected_Type_Decl
               | Libadalang.Common.Ada_Task_Type_Decl =>
               Give_Up (Into, "tasking is not followed");

            when Libadalang.Common.Ada_Object_Decl
               | Libadalang.Common.Ada_Extended_Return_Stmt_Object_Decl
               | Libadalang.Common.Ada_Param_Spec
               | Libadalang.Common.Ada_For_Loop_Var_Decl =>
               Use_Object
                 (Object_Of (Name),
                  (if In_Assertion then Proof_Read else Read));

            when others =>
               null;  --  adalang-analyzer: ignore Null_Statement
         end case;
      end Use_Name;
   begin
      if Libadalang.Analysis.Is_Null (Node) or else not Into.Complete then
         return;
      end if;

      case Node.Kind is
         --  Declared here, run only when called: followed from the call.
         when Libadalang.Common.Ada_Subp_Body
            | Libadalang.Common.Ada_Expr_Function
            | Libadalang.Common.Ada_Subp_Decl
            | Libadalang.Common.Ada_Null_Subp_Decl
            | Libadalang.Common.Ada_Abstract_Subp_Decl
            | Libadalang.Common.Ada_Subp_Renaming_Decl
            | Libadalang.Common.Ada_Subp_Body_Stub
            | Libadalang.Common.Ada_Generic_Subp_Decl
            | Libadalang.Common.Ada_Generic_Subp_Instantiation
            | Libadalang.Common.Ada_Generic_Package_Decl
            | Libadalang.Common.Ada_Defining_Name
            | Libadalang.Common.Ada_End_Name =>
            return;

         when Libadalang.Common.Ada_Task_Body
            | Libadalang.Common.Ada_Single_Task_Decl
            | Libadalang.Common.Ada_Task_Type_Decl
            | Libadalang.Common.Ada_Protected_Body
            | Libadalang.Common.Ada_Single_Protected_Decl
            | Libadalang.Common.Ada_Protected_Type_Decl
            | Libadalang.Common.Ada_Accept_Stmt
            | Libadalang.Common.Ada_Accept_Stmt_With_Stmts
            | Libadalang.Common.Ada_Select_Stmt
            | Libadalang.Common.Ada_Requeue_Stmt =>
            Give_Up (Into, "tasking is not followed");

         when Libadalang.Common.Ada_Generic_Package_Instantiation =>
            Give_Up
              (Into, "the elaboration of a package instance is not followed");

         when Libadalang.Common.Ada_Param_Assoc =>
            --  The designator names a formal of the callee.
            Scan
              (Node.As_Param_Assoc.F_R_Expr, Subprogram, Declaration,
               In_Assertion, Into);

         when Libadalang.Common.Ada_Aspect_Assoc =>
            --  A contract is evaluated, as an assertion; an aspect that
            --  names objects without reading them is not.
            declare
               Aspect : constant String :=
                 Lower_Text (Node.As_Aspect_Assoc.F_Id);
            begin
               if Aspect in "pre" | "post" | "pre'class" | "post'class"
                    | "precondition" | "postcondition" | "refined-post"
                    | "contract-cases" | "subprogram-variant"
                    | "always-terminates" | "exceptional-cases"
                    | "exit-cases"
               then
                  Scan
                    (Node.As_Aspect_Assoc.F_Expr, Subprogram, Declaration,
                     True, Into);
               end if;
            end;

         when Libadalang.Common.Ada_Pragma_Node =>
            declare
               Name : constant String :=
                 Lower_Text (Node.As_Pragma_Node.F_Id);
            begin
               if Name in "assert" | "assume" | "assert-and-cut"
                    | "loop-invariant" | "loop-variant" | "check"
                    | "precondition" | "postcondition"
               then
                  Scan_Children (As_Assertion => True);
               elsif Name not in "unreferenced" | "unused" | "unmodified"
                       | "warnings" | "annotate" | "inline" | "no-inline"
                       | "spark-mode" | "global" | "depends"
                       | "refined-global" | "refined-depends" | "suppress"
                       | "unsuppress" | "style-checks" | "inline-always"
                       | "no-return" | "volatile" | "atomic"
               then
                  Scan_Children;
               end if;
            end;

         when Libadalang.Common.Ada_Assign_Stmt =>
            Write_To (Node.As_Assign_Stmt.F_Dest);
            Scan_Children;

         when Libadalang.Common.Ada_Attribute_Ref =>
            declare
               Attribute : constant String :=
                 Lower_Text (Node.As_Attribute_Ref.F_Attribute);
            begin
               if Attribute in "access" | "unchecked-access"
                    | "unrestricted-access" | "address"
               then
                  --  What is done through the value is not followed: the
                  --  object may be written.
                  declare
                     Object : constant Libadalang.Analysis.Defining_Name :=
                       Object_Of (Node.As_Attribute_Ref.F_Prefix);
                  begin
                     if not Libadalang.Analysis.Is_Null (Object) then
                        Use_Object (Object, Write);
                     end if;
                  end;
                  Scan_Children;
               elsif Attribute in "read" | "write" | "input" | "output"
                       | "put-image"
               then
                  Give_Up
                    (Into,
                     "a stream or image attribute may call a user " &
                     "subprogram");
               elsif Attribute /= "result" then
                  --  The prefix of Result names the function without
                  --  calling it; any other prefix is evaluated.
                  Scan
                    (Node.As_Attribute_Ref.F_Prefix, Subprogram,
                     Declaration, In_Assertion, Into);
                  Scan
                    (Node.As_Attribute_Ref.F_Args, Subprogram, Declaration,
                     In_Assertion, Into);
               end if;
            end;

         when Libadalang.Common.Ada_Call_Expr =>
            declare
               Call : constant Libadalang.Analysis.Call_Expr :=
                 Node.As_Call_Expr;
               Kind : constant Libadalang.Common.Call_Expr_Kind :=
                 Call.P_Kind;
            begin
               if Kind = Libadalang.Common.Call then
                  if Call.F_Name.Kind = Libadalang.Common.Ada_Explicit_Deref
                  then
                     Give_Up (Into, "a call through an access value");
                     return;
                  end if;

                  declare
                     Decl : constant Libadalang.Analysis.Basic_Decl :=
                       Call.F_Name.P_Referenced_Decl;
                  begin
                     if Libadalang.Analysis.Is_Null (Decl)
                       or else Decl.Kind not in
                         Libadalang.Common.Ada_Basic_Subp_Decl
                           | Libadalang.Common.Ada_Base_Subp_Body
                           | Libadalang.Common.Ada_Subp_Body_Stub
                           | Libadalang.Common.Ada_Generic_Subp_Instantiation
                           | Libadalang.Common.Ada_Enum_Literal_Decl
                     then
                        Give_Up
                          (Into,
                           "the call " & Node_Text (Call.F_Name) &
                           " is not to a subprogram that was resolved");
                        return;
                     end if;
                  end;

                  --  What the callee leaves in a formal it may write goes
                  --  into the actual.
                  for Pair of Call.P_Call_Params loop
                     declare
                        Formal : Libadalang.Analysis.Ada_Node :=
                          Libadalang.Analysis.Param (Pair).As_Ada_Node;
                     begin
                        while not Libadalang.Analysis.Is_Null (Formal)
                          and then Formal.Kind /=
                            Libadalang.Common.Ada_Param_Spec
                        loop
                           Formal := Formal.Parent;
                        end loop;
                        --  A formal with no parameter specification is
                        --  that of a predefined operation, of mode in.
                        if not Libadalang.Analysis.Is_Null (Formal)
                          and then Formal.As_Param_Spec.F_Mode.Kind in
                          Libadalang.Common.Ada_Mode_Out
                            | Libadalang.Common.Ada_Mode_In_Out
                        then
                           Write_To (Libadalang.Analysis.Actual (Pair));
                        end if;
                     end;
                  end loop;
               elsif Kind = Libadalang.Common.Array_Index then
                  declare
                     Prefix : constant Libadalang.Analysis.Base_Type_Decl :=
                       Call.F_Name.P_Expression_Type;
                  begin
                     if Libadalang.Analysis.Is_Null (Prefix)
                       or else
                         (not Prefix.P_Is_Array_Type
                          and then not Prefix.P_Is_Access_Type)
                     then
                        Give_Up
                          (Into,
                           "indexing of something other than an array " &
                           "calls a user subprogram");
                        return;
                     end if;
                  end;
               end if;
               Scan_Children;
            end;

         when Libadalang.Common.Ada_Dotted_Name =>
            Use_Name (Node.As_Dotted_Name);
            --  The prefix may hold a call or an index; the selector is
            --  the name just looked at.
            Scan
              (Node.As_Dotted_Name.F_Prefix, Subprogram, Declaration,
               In_Assertion, Into);

         when Libadalang.Common.Ada_Identifier =>
            Use_Name (Node.As_Identifier);

         when Libadalang.Common.Ada_Bin_Op
            | Libadalang.Common.Ada_Relation_Op
            | Libadalang.Common.Ada_Un_Op
            | Libadalang.Common.Ada_Concat_Operand =>
            --  A user-defined operator is a call as any other.
            declare
               Operator : constant Libadalang.Analysis.Name :=
                 (case Node.Kind is
                     when Libadalang.Common.Ada_Un_Op =>
                       Node.As_Un_Op.F_Op.As_Name,
                     when Libadalang.Common.Ada_Concat_Operand =>
                       Node.As_Concat_Operand.F_Operator.As_Name,
                     when others => Node.As_Bin_Op.F_Op.As_Name);
            begin
               Use_Name (Operator);
            end;
            Scan_Children;

         when others =>
            Scan_Children;
      end case;
   exception
      when Exc : others =>
         Give_Up
           (Into,
            "a part of the body was not resolved: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Scan;

   function Body_Effects
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class) return Effects
   is
      Key : constant String :=
        Text_Of (Subprogram.P_Unique_Identifying_Name);
   begin
      if Known.Contains (Key) then
         declare
            Earlier : constant Known_Effects := Known.Element (Key);
            Result  : Effects := Earlier.Value;
         begin
            if Earlier.State = In_Progress then
               Give_Up
                 (Result,
                  "recursion through " &
                  Node_Text (Subprogram.P_Defining_Name) &
                  ", which has no Global aspect");
            end if;
            return Result;
         end;
      end if;

      Known.Insert (Key, (State => In_Progress, Value => <>));

      declare
         Result      : Effects;
         Declaration : constant Libadalang.Analysis.Basic_Decl :=
           Earlier_Declaration (Subprogram);
      begin
         for Index in 1 .. Subprogram.Children_Count loop
            if not Libadalang.Analysis.Is_Null (Subprogram.Child (Index))
              and then Subprogram.Child (Index).Kind not in
                Libadalang.Common.Ada_Subp_Spec
                  | Libadalang.Common.Ada_Overriding_Node
                  | Libadalang.Common.Ada_End_Name
            then
               Scan
                 (Subprogram.Child (Index), Subprogram, Declaration, False,
                  Result);
            end if;
         end loop;

         --  The contracts on the declaration a caller sees are evaluated
         --  around every call too.
         if not Libadalang.Analysis.Is_Null (Declaration) then
            for Index in 1 .. Declaration.Children_Count loop
               if not Libadalang.Analysis.Is_Null (Declaration.Child (Index))
                 and then Declaration.Child (Index).Kind =
                   Libadalang.Common.Ada_Aspect_Spec
               then
                  for Assoc of Declaration.Child (Index).As_Aspect_Spec
                    .F_Aspect_Assocs
                  loop
                     Scan (Assoc, Subprogram, Declaration, True, Result);
                  end loop;
               end if;
            end loop;
         end if;

         Known.Replace (Key, (State => Done, Value => Result));
         return Result;
      end;
   exception
      when Exc : others =>
         declare
            Result : Effects;
         begin
            Give_Up
              (Result,
               "the body was not analyzed: " &
               Ada.Exceptions.Exception_Message (Exc));
            if Known.Contains (Key) then
               Known.Replace (Key, (State => Done, Value => Result));
            end if;
            return Result;
         end;
   end Body_Effects;

   function Touches_Nothing_Outside
     (Callee : Libadalang.Analysis.Basic_Decl'Class;
      Caller : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Touched : constant Effects := Callee_Effects (Callee, Caller);
   begin
      return Touched.Complete and then Touched.Objects.Is_Empty;
   exception
      when others =>
         return False;
   end Touches_Nothing_Outside;

   ------------------------------------------------------------------
   --  Obligations
   ------------------------------------------------------------------

   --  Where an aspect is reported: its name, as GNATprove has it.
   function Aspect_Anchor
     (Expr : Libadalang.Analysis.Expr'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if not Libadalang.Analysis.Is_Null (Expr.Parent)
        and then Expr.Parent.Kind = Libadalang.Common.Ada_Aspect_Assoc
      then
         return Expr.Parent.As_Aspect_Assoc.F_Id.As_Ada_Node;
      end if;
      return Expr.As_Ada_Node;
   end Aspect_Anchor;

   procedure Verify_Global
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Base_Subp_Body'Class;
      Global     : Libadalang.Analysis.Expr)
   is
      Anchor  : constant Libadalang.Analysis.Ada_Node :=
        Aspect_Anchor (Global);
      Subject : constant String :=
        "Global of " & Node_Text (Subprogram.P_Defining_Name);
      Refined : constant Libadalang.Analysis.Expr :=
        Aspect_Expression (Subprogram, "Refined_Global");
      --  The body answers to its refined contract when it has one.
      Listed  : constant Global_Contract :=
        Parse_Global
          (if Libadalang.Analysis.Is_Null (Refined) then Global
           else Refined);
      Actual  : constant Effects := Body_Effects (Subprogram);
      Failure : Unbounded_String;

      procedure Fail (Reason : String) is
      begin
         if Length (Failure) = 0 then
            Failure := To_Unbounded_String (Reason);
         end if;
      end Fail;
   begin
      if not Listed.Resolved then
         Fail ("a name in the aspect was not resolved");
      elsif not Actual.Complete then
         Fail (To_String (Actual.Reason));
      else
         for Item of Actual.Objects loop
            declare
               Name  : constant String := Node_Text (Item.Site);
               Key   : constant String := Key_Of (Item.Site);
               State : constant Libadalang.Analysis.Defining_Name :=
                 (if Listed.Items.Contains (Key)
                  then Libadalang.Analysis.No_Defining_Name
                  else Encapsulating_State (Item.Site, Subprogram));
               Found : constant String :=
                 (if Listed.Items.Contains (Key) then Key
                  elsif not Libadalang.Analysis.Is_Null (State)
                    and then Listed.Items.Contains (Key_Of (State))
                  then Key_Of (State)
                  else "");
            begin
               if Found = "" then
                  Fail (Name & " is used and is not listed");
               else
                  declare
                     Mode : constant Global_Mode :=
                       Listed.Items.Element (Found).Mode;
                  begin
                     if Item.Kind = Write
                       and then Mode not in Output | In_Out
                     then
                        Fail
                          (Name & " may be written and is not listed " &
                           "as Output or In_Out");
                     elsif Item.Kind = Read and then Mode = Proof_In then
                        Fail
                          (Name & " is read outside assertions and is " &
                           "listed as Proof_In");
                     end if;
                  end;
               end if;
            end;
         end loop;
      end if;

      if Length (Failure) = 0 then
         Proof.Register_At
           (Unit             => Unit,
            Node             => Anchor,
            Kind             => Proof.Data_Dependencies_Check,
            Status           => Proof.Proved_Safe,
            Method           => Proof.Flow_Analysis,
            Operation        => Subject,
            Abstract_State   =>
              "every object the body may read or write is allowed by " &
              "the aspect",
            Explanation      =>
              "the subprogram reads and writes no outside object its " &
              "Global aspect does not allow",
            Configuration_Id => Assurance_Profile_Name,
            Final            => True);
      else
         Proof.Register_At
           (Unit               => Unit,
            Node               => Anchor,
            Kind               => Proof.Data_Dependencies_Check,
            Status             => Proof.Unproved,
            Method             => Proof.Flow_Analysis,
            Operation          => Subject,
            Explanation        =>
              "the Global aspect is not shown to cover what the " &
              "subprogram reads and writes",
            Imprecision_Source => To_String (Failure),
            Configuration_Id   => Assurance_Profile_Name,
            Final              => True);
      end if;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("Global aspect not checked for a subprogram: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Verify_Global;

   ------------------------------------------------------------------
   --  Flow dependencies
   ------------------------------------------------------------------

   --  Where a value may come from: the keys of the objects whose values on
   --  entry it may depend on.
   package Key_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

   package Key_Set_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Key_Sets.Set,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Key_Sets."=");

   type Named_Object is record
      Name : Libadalang.Analysis.Defining_Name :=
        Libadalang.Analysis.No_Defining_Name;
   end record;

   package Object_Name_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Named_Object,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Held_Node is record
      Node : Libadalang.Analysis.Ada_Node;
   end record;

   package Node_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Held_Node,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  The object each key stands for.
   Object_Names : Object_Name_Maps.Map;

   --  The output, and the input, that stand for the result of a function.
   Result_Key : constant String := "'result";

   --  The output of a "null =>" association.
   Null_Key : constant String := "null";

   --  A component's path is that of its object, this mark, its name.
   Component_Mark : constant Character := '#';

   --  The subprogram body whose flows are being worked out: what is
   --  declared inside it holds no value on entry.
   Analyzed : Libadalang.Analysis.Ada_Node;

   --  The key of the object Name declares. A formal parameter has the key
   --  of its first declaration, whichever part of the subprogram names it.
   function Object_Key
     (Name : Libadalang.Analysis.Defining_Name'Class) return String
   is
      Canonical : Libadalang.Analysis.Defining_Name := Name.As_Defining_Name;
      Decl      : constant Libadalang.Analysis.Basic_Decl :=
        Name.P_Basic_Decl;
   begin
      if not Libadalang.Analysis.Is_Null (Decl)
        and then Decl.Kind = Libadalang.Common.Ada_Param_Spec
      then
         declare
            Owner : Libadalang.Analysis.Ada_Node := Decl.Parent;
         begin
            while not Libadalang.Analysis.Is_Null (Owner)
              and then Owner.Kind not in Libadalang.Common.Ada_Basic_Decl
            loop
               Owner := Owner.Parent;
            end loop;
            if not Libadalang.Analysis.Is_Null (Owner) then
               declare
                  First : Libadalang.Analysis.Basic_Decl :=
                    Owner.As_Basic_Decl.P_Canonical_Part;
               begin
                  if not Libadalang.Analysis.Is_Null (First)
                    and then First.Kind =
                      Libadalang.Common.Ada_Generic_Subp_Decl
                  then
                     First := First.As_Generic_Subp_Decl.F_Subp_Decl
                                .As_Basic_Decl;
                  end if;
                  if not Libadalang.Analysis.Is_Null (First)
                    and then First.As_Ada_Node /= Owner
                    and then not Libadalang.Analysis.Is_Null
                                   (First.P_Subp_Spec_Or_Null)
                  then
                     for Param of First.P_Subp_Spec_Or_Null.P_Params loop
                        for Id of Param.F_Ids loop
                           if Lower_Text (Id) = Lower_Text (Name) then
                              Canonical := Id.As_Defining_Name;
                           end if;
                        end loop;
                     end loop;
                  end if;
               end;
            end if;
         end;
      end if;

      declare
         Key : constant String := Key_Of (Canonical);
      begin
         --  The latest node: one of an earlier analysis context is gone.
         Object_Names.Include (Key, (Name => Canonical));
         return Key;
      end;
   exception
      when others =>
         return Key_Of (Name);
   end Object_Key;

   function Name_Of (Key : String) return Libadalang.Analysis.Defining_Name
   is (if Object_Names.Contains (Key) then Object_Names.Element (Key).Name
       else Libadalang.Analysis.No_Defining_Name);

   function Root_Of (Path : String) return String is
   begin
      for Index in Path'Range loop
         if Path (Index) = Component_Mark then
            return Path (Path'First .. Index - 1);
         end if;
      end loop;
      return Path;
   end Root_Of;

   --  The path Path is a component of; "" when Path is an object.
   function Enclosing_Path (Path : String) return String is
   begin
      for Index in reverse Path'Range loop
         if Path (Index) = Component_Mark then
            return Path (Path'First .. Index - 1);
         end if;
      end loop;
      return "";
   end Enclosing_Path;

   --  True when Node is written inside Scope. Compared by place in the
   --  source: the same text reached through two instances of a generic is
   --  two nodes.
   function Within
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Scope : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      use type Langkit_Support.Slocs.Line_Number;
      use type Langkit_Support.Slocs.Column_Number;

      Inner : Langkit_Support.Slocs.Source_Location_Range;
      Outer : Langkit_Support.Slocs.Source_Location_Range;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Libadalang.Analysis.Is_Null (Scope)
        or else Node.Unit.Get_Filename /= Scope.Unit.Get_Filename
      then
         return False;
      end if;
      Inner := Node.Sloc_Range;
      Outer := Scope.Sloc_Range;
      return (Outer.Start_Line < Inner.Start_Line
              or else (Outer.Start_Line = Inner.Start_Line
                       and then Outer.Start_Column <= Inner.Start_Column))
        and then (Inner.End_Line < Outer.End_Line
                  or else (Inner.End_Line = Outer.End_Line
                           and then Inner.End_Column <= Outer.End_Column));
   exception
      when others =>
         return False;
   end Within;

   function Is_Formal (Key : String) return Boolean is
      Name : constant Libadalang.Analysis.Defining_Name := Name_Of (Key);
   begin
      return not Libadalang.Analysis.Is_Null (Name)
        and then Name.P_Basic_Decl.Kind = Libadalang.Common.Ada_Param_Spec;
   exception
      when others =>
         return False;
   end Is_Formal;

   --  The keys of the formals of the subprogram Decl declares.
   function Formals_Of
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Key_Sets.Set
   is
      Result : Key_Sets.Set;
      Spec   : constant Libadalang.Analysis.Base_Subp_Spec :=
        Decl.P_Subp_Spec_Or_Null;
   begin
      if not Libadalang.Analysis.Is_Null (Spec) then
         for Param of Spec.P_Params loop
            for Id of Param.F_Ids loop
               Result.Include (Object_Key (Id));
            end loop;
         end loop;
      end if;
      return Result;
   exception
      when others =>
         return Result;
   end Formals_Of;

   --  True when Key is a formal of a subprogram whose body holds Node: an
   --  object Node sees from outside the subprograms nested in that body.
   function Encloses_Formal
     (Key : String; Node : Libadalang.Analysis.Ada_Node'Class)
      return Boolean
   is
      Owner : Libadalang.Analysis.Ada_Node :=
        Name_Of (Key).P_Basic_Decl.As_Ada_Node;
   begin
      while not Libadalang.Analysis.Is_Null (Owner)
        and then (Owner.Kind not in Libadalang.Common.Ada_Basic_Decl
                  or else Owner.Kind = Libadalang.Common.Ada_Param_Spec)
      loop
         Owner := Owner.Parent;
      end loop;
      if Libadalang.Analysis.Is_Null (Owner) then
         return False;
      elsif Within (Node, Owner) then
         return True;
      end if;
      declare
         Completion : constant Libadalang.Analysis.Body_Node :=
           Owner.As_Basic_Decl.P_Body_Part_For_Decl;
      begin
         return not Libadalang.Analysis.Is_Null (Completion)
           and then Within (Node, Completion);
      end;
   exception
      when others =>
         return False;
   end Encloses_Formal;

   function Formal_Mode
     (Key : String) return Libadalang.Common.Ada_Node_Kind_Type
   is
      Mode : constant Libadalang.Analysis.Mode :=
        Name_Of (Key).P_Basic_Decl.As_Param_Spec.F_Mode;
   begin
      if Libadalang.Analysis.Is_Null (Mode) then
         return Libadalang.Common.Ada_Mode_Default;
      end if;
      return Mode.Kind;
   end Formal_Mode;

   --  True when the object of Key is declared in the body being analyzed:
   --  it holds no value on entry.
   function Is_Local_Key (Key : String) return Boolean is
      Name : constant Libadalang.Analysis.Defining_Name := Name_Of (Key);
   begin
      return not Libadalang.Analysis.Is_Null (Name)
        and then Within (Name, Analyzed)
        and then Name.P_Basic_Decl.Kind /= Libadalang.Common.Ada_Param_Spec;
   exception
      when others =>
         return False;
   end Is_Local_Key;

   ------------------------------------------------------------------
   --  Record components
   ------------------------------------------------------------------

   --  The declaration of a record type Decl stands for, behind subtypes and
   --  private views; null when it is not a record type declared with all
   --  its components.
   function Record_View
     (Decl : Libadalang.Analysis.Base_Type_Decl)
      return Libadalang.Analysis.Type_Decl
   is
      Full : Libadalang.Analysis.Base_Type_Decl := Decl;
   begin
      for Step in 1 .. 8 loop
         exit when Libadalang.Analysis.Is_Null (Full);
         if Full.Kind = Libadalang.Common.Ada_Subtype_Decl then
            Full := Full.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
         else
            declare
               View : constant Libadalang.Analysis.Base_Type_Decl :=
                 Full.P_Full_View;
            begin
               exit when Libadalang.Analysis.Is_Null (View)
                 or else View.As_Ada_Node = Full.As_Ada_Node;
               Full := View;
            end;
         end if;
      end loop;

      if Libadalang.Analysis.Is_Null (Full)
        or else Full.Kind /= Libadalang.Common.Ada_Concrete_Type_Decl
        or else Full.As_Type_Decl.F_Type_Def.Kind /=
          Libadalang.Common.Ada_Record_Type_Def
      then
         return Libadalang.Analysis.No_Type_Decl;
      end if;
      return Full.As_Type_Decl;
   exception
      when others =>
         return Libadalang.Analysis.No_Type_Decl;
   end Record_View;

   --  Calls Visit for each discriminant and component of the record type
   --  Decl, those of every variant.
   procedure For_Each_Component
     (Decl  : Libadalang.Analysis.Type_Decl;
      Visit : not null access procedure
        (Name : String; Of_Type : Libadalang.Analysis.Type_Expr))
   is
      procedure Add_List (List : Libadalang.Analysis.Component_List) is
      begin
         if Libadalang.Analysis.Is_Null (List) then
            return;
         end if;
         for Item of List.F_Components loop
            if Item.Kind = Libadalang.Common.Ada_Component_Decl then
               for Id of Item.As_Component_Decl.F_Ids loop
                  Visit
                    (Lower_Text (Id),
                     Item.As_Component_Decl.F_Component_Def.F_Type_Expr);
               end loop;
            end if;
         end loop;
         if not Libadalang.Analysis.Is_Null (List.F_Variant_Part) then
            for Item of List.F_Variant_Part.F_Variant loop
               Add_List (Item.As_Variant.F_Components);
            end loop;
         end if;
      end Add_List;

      Discriminants : constant Libadalang.Analysis.Discriminant_Part :=
        Decl.F_Discriminants;
   begin
      if not Libadalang.Analysis.Is_Null (Discriminants)
        and then Discriminants.Kind =
          Libadalang.Common.Ada_Known_Discriminant_Part
      then
         for Spec of Discriminants.As_Known_Discriminant_Part.F_Discr_Specs
         loop
            for Id of Spec.F_Ids loop
               Visit (Lower_Text (Id), Spec.F_Type_Expr);
            end loop;
         end loop;
      end if;
      Add_List
        (Decl.F_Type_Def.As_Record_Type_Def.F_Record_Def.F_Components);
   end For_Each_Component;

   --  The type of the object or component at Path; null when not known.
   function Path_Type
     (Path : String) return Libadalang.Analysis.Base_Type_Decl
   is
      None   : Libadalang.Analysis.Base_Type_Decl renames
        Libadalang.Analysis.No_Base_Type_Decl;
      Root   : constant String := Root_Of (Path);
      Name   : constant Libadalang.Analysis.Defining_Name := Name_Of (Root);
      Result : Libadalang.Analysis.Base_Type_Decl;
      First  : Positive := Path'First + Root'Length + 1;
   begin
      if Libadalang.Analysis.Is_Null (Name) then
         return None;
      end if;
      case Name.P_Basic_Decl.Kind is
         when Libadalang.Common.Ada_Object_Decl
            | Libadalang.Common.Ada_Extended_Return_Stmt_Object_Decl =>
            Result := Name.P_Basic_Decl.As_Object_Decl.F_Type_Expr
                        .P_Designated_Type_Decl;
         when Libadalang.Common.Ada_Param_Spec =>
            Result := Name.P_Basic_Decl.As_Param_Spec.F_Type_Expr
                        .P_Designated_Type_Decl;
         when others =>
            return None;
      end case;

      while First <= Path'Last and then not Libadalang.Analysis.Is_Null (Result)
      loop
         declare
            Last : Natural := Path'Last;
            View : constant Libadalang.Analysis.Type_Decl :=
              Record_View (Result);
            Next : Libadalang.Analysis.Base_Type_Decl := None;
         begin
            for Index in First .. Path'Last loop
               if Path (Index) = Component_Mark then
                  Last := Index - 1;
                  exit;
               end if;
            end loop;
            if Libadalang.Analysis.Is_Null (View) then
               return None;
            end if;
            declare
               Wanted : constant String := Path (First .. Last);
               procedure Visit
                 (Component : String;
                  Of_Type   : Libadalang.Analysis.Type_Expr) is
               begin
                  if Component = Wanted then
                     Next := Of_Type.P_Designated_Type_Decl;
                  end if;
               end Visit;
            begin
               For_Each_Component (View, Visit'Access);
            end;
            Result := Next;
            First := Last + 2;
         end;
      end loop;
      return Result;
   exception
      when others =>
         return None;
   end Path_Type;

   --  True when the object of Root may be an array: its bounds are then a
   --  part of its value.
   function Is_Array_Object (Root : String) return Boolean is
      Name : constant Libadalang.Analysis.Defining_Name := Name_Of (Root);
   begin
      if Libadalang.Analysis.Is_Null (Name)
        or else Name.P_Basic_Decl.Kind not in
          Libadalang.Common.Ada_Object_Decl
            | Libadalang.Common.Ada_Extended_Return_Stmt_Object_Decl
            | Libadalang.Common.Ada_Param_Spec
      then
         return False;
      end if;
      declare
         Of_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Path_Type (Root);
      begin
         return Libadalang.Analysis.Is_Null (Of_Type)
           or else Of_Type.P_Is_Array_Type;
      end;
   exception
      when others =>
         return True;
   end Is_Array_Object;

   function Component_Names (Path : String) return Key_Sets.Set is
      Result : Key_Sets.Set;
      View   : constant Libadalang.Analysis.Type_Decl :=
        Record_View (Path_Type (Path));

      procedure Visit
        (Name : String; Of_Type : Libadalang.Analysis.Type_Expr)
      is
         pragma Unreferenced (Of_Type);
      begin
         Result.Include (Name);
      end Visit;
   begin
      if not Libadalang.Analysis.Is_Null (View) then
         For_Each_Component (View, Visit'Access);
      end if;
      return Result;
   exception
      when others =>
         return Key_Sets.Empty_Set;
   end Component_Names;

   ------------------------------------------------------------------
   --  States
   ------------------------------------------------------------------

   --  What the objects hold at a point of a body. An object or component
   --  with no entry holds what the nearest enclosing one with an entry
   --  holds, or, when none has, its value on entry. An exploded one holds
   --  its components, each of which has an entry or is exploded in turn.
   type Flow_State is record
      Values   : Key_Set_Maps.Map;
      Exploded : Key_Sets.Set;
      Alive    : Boolean := True;
   end record;

   Dead : constant Flow_State := (Alive => False, others => <>);

   --  The objects of the body being analyzed whose value on entry is not
   --  an input: its out parameters and the objects its Global aspect lists
   --  as Output. A read of one before it is written is a failure of an
   --  initialization obligation, not a flow.
   Without_Input : Key_Sets.Set;

   package Boolean_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Boolean,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  The constants whose value depends on no variable, by key.
   Constant_Keys : Boolean_Maps.Map;

   function Is_Constant_Key (Key : String) return Boolean is
   begin
      if not Constant_Keys.Contains (Key) then
         declare
            Name : constant Libadalang.Analysis.Defining_Name := Name_Of (Key);
         begin
            Constant_Keys.Insert
              (Key,
               not Libadalang.Analysis.Is_Null (Name)
               and then Is_Not_A_Global (Name));
         end;
      end if;
      return Constant_Keys.Element (Key);
   exception
      when others =>
         return False;
   end Is_Constant_Key;

   function Has_No_Input (Root : String) return Boolean is
      Current : Unbounded_String := To_Unbounded_String (Root);
   begin
      for Step in 1 .. 8 loop
         if Without_Input.Contains (To_String (Current)) then
            return True;
         end if;
         declare
            Name  : constant Libadalang.Analysis.Defining_Name :=
              Name_Of (To_String (Current));
            State : Libadalang.Analysis.Defining_Name;
         begin
            exit when Libadalang.Analysis.Is_Null (Name);
            State := Encapsulating_State (Name, Name);
            exit when Libadalang.Analysis.Is_Null (State);
            Current := To_Unbounded_String (Object_Key (State));
         end;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Has_No_Input;

   function Initial (Root : String) return Key_Sets.Set is
     (if Is_Local_Key (Root) or else Is_Constant_Key (Root)
         or else Has_No_Input (Root)
      then Key_Sets.Empty_Set
      else Key_Sets.To_Set (Root));

   function Children (S : Flow_State; Path : String) return Key_Sets.Set is
      Result : Key_Sets.Set;
   begin
      for Position in S.Values.Iterate loop
         if Enclosing_Path (Key_Set_Maps.Key (Position)) = Path then
            Result.Include (Key_Set_Maps.Key (Position));
         end if;
      end loop;
      for Item of S.Exploded loop
         if Enclosing_Path (Item) = Path then
            Result.Include (Item);
         end if;
      end loop;
      return Result;
   end Children;

   function Value (S : Flow_State; Path : String) return Key_Sets.Set is
   begin
      if S.Exploded.Contains (Path) then
         declare
            Result : Key_Sets.Set;
         begin
            for Child of Children (S, Path) loop
               Result.Union (Value (S, Child));
            end loop;
            return Result;
         end;
      end if;

      declare
         Current : Unbounded_String := To_Unbounded_String (Path);
      begin
         while Length (Current) > 0 loop
            if S.Values.Contains (To_String (Current)) then
               return S.Values.Element (To_String (Current));
            end if;
            Current :=
              To_Unbounded_String (Enclosing_Path (To_String (Current)));
         end loop;
      end;
      return Initial (Root_Of (Path));
   end Value;

   --  Splits Path, whose enclosing objects are all split, into its
   --  components, each holding what Path held.
   procedure Explode
     (S : in out Flow_State; Path : String; Done : out Boolean)
   is
      Names : constant Key_Sets.Set := Component_Names (Path);
      Base  : Key_Sets.Set;
   begin
      Done := True;
      if S.Exploded.Contains (Path) then
         return;
      elsif Names.Is_Empty then
         Done := False;
         return;
      end if;
      Base := Value (S, Path);
      if S.Values.Contains (Path) then
         S.Values.Delete (Path);
      end if;
      S.Exploded.Insert (Path);
      for Name of Names loop
         S.Values.Include (Path & Component_Mark & Name, Base);
      end loop;
   end Explode;

   --  Splits each object and component enclosing Path. Reached is the
   --  deepest of them that holds Path whole: Path itself unless one could
   --  not be split.
   procedure Open_Path
     (S       : in out Flow_State;
      Path    : String;
      Reached : out Unbounded_String)
   is
      Current : Unbounded_String := To_Unbounded_String (Root_Of (Path));
      Done    : Boolean;
   begin
      while Length (Current) < Path'Length loop
         Explode (S, To_String (Current), Done);
         if not Done then
            Reached := Current;
            return;
         end if;
         declare
            Next : Natural := Path'Last;
         begin
            for Index in Path'First + Length (Current) + 1 .. Path'Last loop
               if Path (Index) = Component_Mark then
                  Next := Index - 1;
                  exit;
               end if;
            end loop;
            Current := To_Unbounded_String (Path (Path'First .. Next));
         end;
      end loop;
      Reached := To_Unbounded_String (Path);
   end Open_Path;

   --  Adds Deps to what Path and every part of it may hold.
   procedure Add_To
     (S : in out Flow_State; Path : String; Deps : Key_Sets.Set) is
   begin
      if S.Exploded.Contains (Path) then
         for Child of Children (S, Path) loop
            Add_To (S, Child, Deps);
         end loop;
      else
         declare
            Result : Key_Sets.Set := Value (S, Path);
         begin
            Result.Union (Deps);
            S.Values.Include (Path, Result);
         end;
      end if;
   end Add_To;

   --  Forgets what Path and its parts hold.
   procedure Remove (S : in out Flow_State; Path : String) is
      Prefix : constant String := Path & Component_Mark;
      Gone   : Key_Sets.Set;

      function Under (Key : String) return Boolean
      is (Key = Path
          or else (Key'Length > Prefix'Length
                   and then Key (Key'First .. Key'First + Prefix'Length - 1)
                              = Prefix));
   begin
      for Position in S.Values.Iterate loop
         if Under (Key_Set_Maps.Key (Position)) then
            Gone.Include (Key_Set_Maps.Key (Position));
         end if;
      end loop;
      for Key of Gone loop
         S.Values.Delete (Key);
      end loop;
      Gone.Clear;
      for Key of S.Exploded loop
         if Under (Key) then
            Gone.Include (Key);
         end if;
      end loop;
      for Key of Gone loop
         S.Exploded.Delete (Key);
      end loop;
   end Remove;

   --  Path now holds Deps, and nothing else when Whole: it is given a new
   --  value as a whole. Otherwise only some part of it is.
   procedure Write
     (S     : in out Flow_State;
      Path  : String;
      Deps  : Key_Sets.Set;
      Whole : Boolean)
   is
      Reached : Unbounded_String;
   begin
      Open_Path (S, Path, Reached);
      if To_String (Reached) /= Path then
         Add_To (S, To_String (Reached), Deps);
      elsif Whole then
         Remove (S, Path);
         S.Values.Include (Path, Deps);
      else
         Add_To (S, Path, Deps);
      end if;
   end Write;

   --  What either of two paths may leave. False in Done when the two could
   --  not be put in the same shape.
   procedure Join
     (Into   : in out Flow_State;
      Source : Flow_State;
      Done   : in out Boolean) is
   begin
      if not Source.Alive then
         return;
      elsif not Into.Alive then
         Into := Source;
         return;
      end if;

      declare
         Left   : Flow_State := Into;
         Right  : Flow_State := Source;
         Result : Flow_State;
         Split  : Boolean;
      begin
         Result.Exploded := Key_Sets.Union (Left.Exploded, Right.Exploded);
         for Path of Result.Exploded loop
            Explode (Left, Path, Split);
            Done := Done and then Split;
            Explode (Right, Path, Split);
            Done := Done and then Split;
         end loop;
         for Position in Left.Values.Iterate loop
            Result.Values.Include
              (Key_Set_Maps.Key (Position),
               Key_Sets.Union
                 (Key_Set_Maps.Element (Position),
                  Value (Right, Key_Set_Maps.Key (Position))));
         end loop;
         for Position in Right.Values.Iterate loop
            if not Result.Values.Contains (Key_Set_Maps.Key (Position)) then
               Result.Values.Include
                 (Key_Set_Maps.Key (Position),
                  Key_Sets.Union
                    (Key_Set_Maps.Element (Position),
                     Value (Left, Key_Set_Maps.Key (Position))));
            end if;
         end loop;
         Into := Result;
      end;
   end Join;

   function Same (Left, Right : Flow_State) return Boolean
   is (Left.Alive = Right.Alive
       and then Key_Set_Maps."=" (Left.Values, Right.Values)
       and then Key_Sets."=" (Left.Exploded, Right.Exploded));

   ------------------------------------------------------------------
   --  Dependency contracts
   ------------------------------------------------------------------

   --  For each output of a subprogram, the inputs its value on exit may
   --  depend on. All_Inputs: each output may depend on every input and on
   --  every actual parameter. Known is False when that is not known.
   type Flow_Summary is record
      Known      : Boolean := True;
      Reason     : Unbounded_String;
      All_Inputs : Boolean := False;
      Flows      : Key_Set_Maps.Map;
   end record;

   function Unknown (Reason : String) return Flow_Summary
   is (Known => False, Reason => To_Unbounded_String (Reason), others => <>);

   --  What a Depends or Refined_Depends aspect says. Names holds every
   --  object it names.
   type Dependency_Contract is record
      Resolved : Boolean := True;
      Flows    : Key_Set_Maps.Map;
      Names    : Key_Sets.Set;
   end record;

   function Parse_Depends
     (Expr : Libadalang.Analysis.Expr'Class) return Dependency_Contract
   is
      Result : Dependency_Contract;

      function Name_Key (Node : Libadalang.Analysis.Ada_Node'Class)
        return String is
      begin
         if Node.Kind = Libadalang.Common.Ada_Null_Literal then
            return Null_Key;
         elsif Node.Kind = Libadalang.Common.Ada_Attribute_Ref
           and then Lower_Text (Node.As_Attribute_Ref.F_Attribute) = "result"
         then
            return Result_Key;
         elsif Node.Kind in Libadalang.Common.Ada_Identifier
                 | Libadalang.Common.Ada_Dotted_Name
         then
            declare
               Site : constant Libadalang.Analysis.Defining_Name :=
                 Node.As_Name.P_Referenced_Defining_Name;
            begin
               if not Libadalang.Analysis.Is_Null (Site) then
                  return Object_Key (Site);
               end if;
            end;
         end if;
         Result.Resolved := False;
         return "";
      end Name_Key;

      --  The names a list of the aspect holds: one name, null, or a
      --  parenthesized list.
      procedure Add_Names
        (Node : Libadalang.Analysis.Ada_Node'Class;
         Into : in out Key_Sets.Set) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
            Add_Names (Node.As_Paren_Expr.F_Expr, Into);
         elsif Node.Kind in Libadalang.Common.Ada_Base_Aggregate then
            for Item of Node.As_Base_Aggregate.F_Assocs loop
               if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc
                 and then Item.As_Aggregate_Assoc.F_Designators
                            .Children_Count = 0
               then
                  Add_Names (Item.As_Aggregate_Assoc.F_R_Expr, Into);
               else
                  Result.Resolved := False;
               end if;
            end loop;
         else
            declare
               Key : constant String := Name_Key (Node);
            begin
               if Key /= "" and then Key /= Null_Key then
                  Into.Include (Key);
               end if;
            end;
         end if;
      end Add_Names;
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind = Libadalang.Common.Ada_Null_Literal
      then
         return Result;
      elsif Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate then
         Result.Resolved := False;
         return Result;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind /= Libadalang.Common.Ada_Aggregate_Assoc then
            Result.Resolved := False;
         else
            declare
               Assoc   : constant Libadalang.Analysis.Aggregate_Assoc :=
                 Item.As_Aggregate_Assoc;
               Inputs  : Key_Sets.Set;
               Outputs : Key_Sets.Set;
               Plus    : Boolean := False;
               Right   : Libadalang.Analysis.Ada_Node :=
                 Assoc.F_R_Expr.As_Ada_Node;
            begin
               if Right.Kind = Libadalang.Common.Ada_Un_Op
                 and then Right.As_Un_Op.F_Op.Kind =
                   Libadalang.Common.Ada_Op_Plus
               then
                  Plus := True;
                  Right := Right.As_Un_Op.F_Expr.As_Ada_Node;
               end if;
               if Right.Kind /= Libadalang.Common.Ada_Null_Literal then
                  Add_Names (Right, Inputs);
               end if;

               for Designator of Assoc.F_Designators loop
                  if Designator.Kind = Libadalang.Common.Ada_Null_Literal then
                     Outputs.Include (Null_Key);
                  elsif Designator.Kind = Libadalang.Common.Ada_Attribute_Ref
                  then
                     declare
                        Key : constant String := Name_Key (Designator);
                     begin
                        if Key /= "" then
                           Outputs.Include (Key);
                        end if;
                     end;
                  else
                     Add_Names (Designator, Outputs);
                  end if;
               end loop;

               for Output of Outputs loop
                  declare
                     Listed : Key_Sets.Set := Inputs;
                  begin
                     if Plus and then Output /= Null_Key then
                        Listed.Include (Output);
                     end if;
                     if Result.Flows.Contains (Output) then
                        Listed.Union (Result.Flows.Element (Output));
                     end if;
                     Result.Flows.Include (Output, Listed);
                  end;
                  if Output /= Null_Key then
                     Result.Names.Include (Output);
                  end if;
               end loop;
               Result.Names.Union (Inputs);
            end;
         end if;
      end loop;
      return Result;
   exception
      when others =>
         Result.Resolved := False;
         return Result;
   end Parse_Depends;

   --  The summary of a subprogram whose contract is a Depends aspect.
   function From_Depends
     (Expr : Libadalang.Analysis.Expr'Class) return Flow_Summary
   is
      Listed : constant Dependency_Contract := Parse_Depends (Expr);
   begin
      if not Listed.Resolved then
         return Unknown ("a Depends aspect of a callee was not resolved");
      end if;
      return (Known => True, Reason => <>, All_Inputs => False,
              Flows => Listed.Flows);
   end From_Depends;

   --  True when the bounds of an object of the subtype Of_Type are those of
   --  the subtype, worked out from no variable.
   function Fixed_Bounds (Of_Type : Libadalang.Analysis.Type_Expr'Class)
     return Boolean
   is
      Decl : constant Libadalang.Analysis.Base_Type_Decl :=
        Of_Type.P_Designated_Type_Decl;
   begin
      if not Of_Type.P_Is_Definite_Subtype
        or else Libadalang.Analysis.Is_Null (Decl)
      then
         return False;
      end if;
      return Is_Variable_Free (Of_Type)
        and then Is_Variable_Free
                   (if Decl.Kind = Libadalang.Common.Ada_Subtype_Decl
                    then Decl.As_Subtype_Decl.F_Subtype.As_Ada_Node
                    else Decl.As_Ada_Node);
   exception
      when others =>
         return False;
   end Fixed_Bounds;

   --  An out parameter of an indefinite type brings in its bounds.
   function Brings_Bounds (Param : Libadalang.Analysis.Param_Spec)
     return Boolean is
   begin
      return not Param.F_Type_Expr.P_Is_Definite_Subtype;
   exception
      when others =>
         return True;
   end Brings_Bounds;

   --  The summary of a subprogram whose contract is a Global aspect only:
   --  each output may depend on every input.
   function From_Global
     (Decl   : Libadalang.Analysis.Basic_Decl'Class;
      Global : Libadalang.Analysis.Expr'Class) return Flow_Summary
   is
      Inputs, Outputs : Key_Sets.Set;
      Result          : Flow_Summary;
      Spec            : constant Libadalang.Analysis.Base_Subp_Spec :=
        Decl.P_Subp_Spec_Or_Null;
   begin
      if Libadalang.Analysis.Is_Null (Spec) then
         return Unknown ("the parameters of a callee were not found");
      end if;
      for Param of Spec.P_Params loop
         for Id of Param.F_Ids loop
            declare
               Key  : constant String := Object_Key (Id);
               Mode : constant Libadalang.Common.Ada_Node_Kind_Type :=
                 (if Libadalang.Analysis.Is_Null (Param.F_Mode)
                  then Libadalang.Common.Ada_Mode_Default
                  else Param.F_Mode.Kind);
            begin
               case Mode is
                  when Libadalang.Common.Ada_Mode_Out =>
                     Outputs.Include (Key);
                     if Brings_Bounds (Param) then
                        Inputs.Include (Key);
                     end if;
                  when Libadalang.Common.Ada_Mode_In_Out =>
                     Outputs.Include (Key);
                     Inputs.Include (Key);
                  when others =>
                     Inputs.Include (Key);
               end case;
            end;
         end loop;
      end loop;
      if not Libadalang.Analysis.Is_Null (Spec.P_Returns) then
         Outputs.Include (Result_Key);
      end if;

      if not Libadalang.Analysis.Is_Null (Global) then
         declare
            Listed : constant Global_Contract := Parse_Global (Global);
         begin
            if not Listed.Resolved then
               return Unknown ("the Global aspect of a callee was not resolved");
            end if;
            for Item of Listed.Items loop
               declare
                  Key : constant String := Object_Key (Item.Site);
               begin
                  if Item.Mode in Input | In_Out then
                     Inputs.Include (Key);
                  end if;
                  if Item.Mode in Output | In_Out then
                     Outputs.Include (Key);
                  end if;
               end;
            end loop;
         end;
      end if;

      for Output of Outputs loop
         Result.Flows.Include (Output, Inputs);
      end loop;
      return Result;
   exception
      when Exc : others =>
         return Unknown
           ("the contract of a callee was not read: " &
            Ada.Exceptions.Exception_Message (Exc));
   end From_Global;

   --  The body being analyzed and the objects without input on entry.
   type Saved_Context is record
      Body_Node : Libadalang.Analysis.Ada_Node;
      Inputs    : Key_Sets.Set;
   end record;

   function Current_Context return Saved_Context
   is ((Body_Node => Analyzed, Inputs => Without_Input));

   procedure Restore (Saved : Saved_Context) is
   begin
      Analyzed := Saved.Body_Node;
      Without_Input := Saved.Inputs;
   end Restore;

   --  Makes Subprogram the body being analyzed.
   procedure Enter (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class) is
      Global : constant Libadalang.Analysis.Expr :=
        (if Libadalang.Analysis.Is_Null
              (Aspect_Expression (Subprogram, "Refined_Global"))
         then Contract (Subprogram, "Global")
         else Aspect_Expression (Subprogram, "Refined_Global"));
      Spec   : constant Libadalang.Analysis.Base_Subp_Spec :=
        Subprogram.P_Subp_Spec_Or_Null;
   begin
      Analyzed := Subprogram.As_Ada_Node;
      Without_Input.Clear;
      if not Libadalang.Analysis.Is_Null (Spec) then
         for Param of Spec.P_Params loop
            if not Libadalang.Analysis.Is_Null (Param.F_Mode)
              and then Param.F_Mode.Kind = Libadalang.Common.Ada_Mode_Out
            then
               for Id of Param.F_Ids loop
                  Without_Input.Include (Object_Key (Id));
               end loop;
            end if;
         end loop;
      end if;
      if not Libadalang.Analysis.Is_Null (Global) then
         declare
            Listed : constant Global_Contract := Parse_Global (Global);
         begin
            for Item of Listed.Items loop
               if Item.Mode = Output then
                  Without_Input.Include (Object_Key (Item.Site));
               end if;
            end loop;
         end;
      end if;
   end Enter;

   --  The summary of a subprogram from what its body touches: each output
   --  may depend on every input.
   function From_Effects
     (Decl    : Libadalang.Analysis.Basic_Decl'Class;
      Touched : Effects) return Flow_Summary
   is
      Result : Flow_Summary := From_Global (Decl, Libadalang.Analysis.No_Expr);
      Inputs, Outputs : Key_Sets.Set;
   begin
      if not Result.Known then
         return Result;
      end if;
      for Position in Result.Flows.Iterate loop
         Outputs.Include (Key_Set_Maps.Key (Position));
         Inputs.Union (Key_Set_Maps.Element (Position));
      end loop;
      for Item of Touched.Objects loop
         --  What is written may keep a part of what it held.
         if Item.Kind in Read | Write then
            Inputs.Include (Object_Key (Item.Site));
         end if;
         if Item.Kind = Write then
            Outputs.Include (Object_Key (Item.Site));
         end if;
      end loop;
      Result.Flows.Clear;
      for Output of Outputs loop
         Result.Flows.Include (Output, Inputs);
      end loop;
      return Result;
   end From_Effects;

   --  What a body leaves: the state at its normal exits and what a function
   --  returns. Known is False when it could not be worked out.
   type Body_Flows is record
      Known  : Boolean := True;
      Reason : Unbounded_String;
      Final  : Flow_State := Dead;
      Result : Key_Sets.Set;
   end record;

   function Analyze_Body
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class)
      return Body_Flows;

   type Summary_State is (In_Progress, Done);

   type Known_Summary is record
      State : Summary_State := In_Progress;
      Value : Flow_Summary;
   end record;

   package Summary_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Known_Summary,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Body_Summaries : Summary_Maps.Map;

   --  The summary of a body without a dependency contract, from the body.
   function From_Body
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class)
      return Flow_Summary
   is
      Key : constant String := Text_Of (Subprogram.P_Unique_Identifying_Name);
   begin
      if Body_Summaries.Contains (Key) then
         if Body_Summaries.Element (Key).State = In_Progress then
            return Unknown
              ("recursion through " &
               Node_Text (Subprogram.P_Defining_Name) &
               ", which has no Depends aspect");
         end if;
         return Body_Summaries.Element (Key).Value;
      end if;
      Body_Summaries.Insert (Key, (State => In_Progress, Value => <>));

      declare
         Saved  : constant Saved_Context := Current_Context;
         Flows  : constant Body_Flows := Analyze_Body (Subprogram);
         Result : Flow_Summary;
      begin
         if not Flows.Known then
            Result := Unknown (To_String (Flows.Reason));
         elsif Flows.Final.Alive or else not Flows.Result.Is_Empty then
            declare
               Spec : constant Libadalang.Analysis.Base_Subp_Spec :=
                 Subprogram.P_Subp_Spec_Or_Null;
               Roots : Key_Sets.Set;
            begin
               --  Each formal the body may write, each object outside it
               --  that it writes.
               for Param of Spec.P_Params loop
                  for Id of Param.F_Ids loop
                     declare
                        Formal : constant String := Object_Key (Id);
                     begin
                        if Formal_Mode (Formal) in
                          Libadalang.Common.Ada_Mode_Out
                            | Libadalang.Common.Ada_Mode_In_Out
                        then
                           Roots.Include (Formal);
                        end if;
                     end;
                  end loop;
               end loop;
               Enter (Subprogram);
               for Position in Flows.Final.Values.Iterate loop
                  declare
                     Root : constant String :=
                       Root_Of (Key_Set_Maps.Key (Position));
                  begin
                     if not Is_Local_Key (Root) then
                        Roots.Include (Root);
                     end if;
                  end;
               end loop;
               for Root of Roots loop
                  if Flows.Final.Alive then
                     Result.Flows.Include (Root, Value (Flows.Final, Root));
                  else
                     Result.Flows.Include (Root, Key_Sets.Empty_Set);
                  end if;
               end loop;
               Restore (Saved);
               Result.Flows.Include (Result_Key, Flows.Result);
            end;
         end if;
         Body_Summaries.Replace (Key, (State => Done, Value => Result));
         return Result;
      end;
   exception
      when Exc : others =>
         return Unknown
           ("the body of a callee was not analyzed: " &
            Ada.Exceptions.Exception_Message (Exc));
   end From_Body;

   --  An intrinsic subprogram has no state: what it returns comes from its
   --  parameters.
   function Is_Intrinsic
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Convention : constant Libadalang.Analysis.Expr :=
        Aspect_Expression (Decl, "Convention");
   begin
      return Decl.P_Is_Imported
        and then not Libadalang.Analysis.Is_Null (Convention)
        and then Lower_Text (Convention) = "intrinsic";
   exception
      when others =>
         return False;
   end Is_Intrinsic;

   --  True when the generic formal subprogram Formal is given, in every
   --  instantiation of its generic unit in this run, a subprogram that
   --  touches no object outside it. Its parameters are then all it works
   --  from and on.
   function Actuals_Keep_To_Themselves
     (Formal : Libadalang.Analysis.Basic_Decl'Class;
      Depth  : Natural) return Boolean
   is
      Max_Depth : constant := 4;
      Unit      : constant String :=
        Subprogram_Summaries.Generic_Unit_Key (Formal);
      Wanted    : constant String := Key_Of (Formal.P_Defining_Name);
      Found     : Boolean := False;
      Kept      : Boolean := True;
      Lost      : Boolean;

      procedure Visit (Node : Libadalang.Analysis.Generic_Instantiation) is
         Actual : Libadalang.Analysis.Expr;
      begin
         Found := True;
         for Pair of Node.P_Inst_Params loop
            if Key_Of (Libadalang.Analysis.Param (Pair)) = Wanted then
               Actual := Libadalang.Analysis.Actual (Pair).As_Expr;
            end if;
         end loop;
         if Libadalang.Analysis.Is_Null (Actual)
           or else Actual.Kind not in Libadalang.Common.Ada_Name
         then
            Kept := False;
            return;
         end if;
         declare
            Target : constant Libadalang.Analysis.Basic_Decl :=
              Actual.As_Name.P_Referenced_Decl;
         begin
            if Libadalang.Analysis.Is_Null (Target) then
               Kept := False;
            elsif Target.Kind in Libadalang.Common.Ada_Formal_Subp_Decl then
               Kept := Kept
                 and then Actuals_Keep_To_Themselves (Target, Depth + 1);
            else
               Kept := Kept and then Touches_Nothing_Outside (Target, Node);
            end if;
         end;
      exception
         when others =>
            Kept := False;
      end Visit;
   begin
      if Unit = "" or else Depth > Max_Depth then
         return False;
      end if;
      Subprogram_Summaries.For_Each_Instantiation
        (Unit, Formal, Visit'Access, Lost);
      return Found and then Kept and then not Lost;
   exception
      when others =>
         return False;
   end Actuals_Keep_To_Themselves;

   --  What a call to Decl from Caller may make of its outputs.
   function Callee_Summary
     (Decl   : Libadalang.Analysis.Basic_Decl'Class;
      Caller : Libadalang.Analysis.Ada_Node'Class;
      Depth  : Natural := 0) return Flow_Summary
   is
      Max_Renamings : constant := 8;
      Name          : constant String :=
        (if Libadalang.Analysis.Is_Null (Decl) then "a subprogram"
         else Node_Text (Decl.P_Defining_Name));
   begin
      if Libadalang.Analysis.Is_Null (Decl) or else Depth > Max_Renamings
      then
         return Unknown ("a call was not resolved");
      end if;

      case Decl.Kind is
         when Libadalang.Common.Ada_Enum_Literal_Decl
            | Libadalang.Common.Ada_Synthetic_Subp_Decl =>
            return (All_Inputs => True, others => <>);

         when Libadalang.Common.Ada_Null_Subp_Decl =>
            return (others => <>);

         when Libadalang.Common.Ada_Subp_Renaming_Decl =>
            declare
               Renamed : constant Libadalang.Analysis.Name :=
                 Decl.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object;
            begin
               if Renamed.Kind = Libadalang.Common.Ada_Attribute_Ref then
                  return (All_Inputs => True, others => <>);
               end if;
               return Callee_Summary
                 (Renamed.P_Referenced_Decl, Caller, Depth + 1);
            end;

         when Libadalang.Common.Ada_Generic_Subp_Instantiation =>
            declare
               Generic_Name : constant String :=
                 Normalize_Rule_Name
                   (Text_Of
                      (Decl.As_Generic_Subp_Instantiation
                         .F_Generic_Subp_Name.P_Referenced_Decl
                         .P_Fully_Qualified_Name));
            begin
               if Generic_Name in "ada.unchecked-conversion"
                    | "unchecked-conversion"
               then
                  return (All_Inputs => True, others => <>);
               end if;
               declare
                  Depends : constant Libadalang.Analysis.Expr :=
                    Generic_Contract (Decl, "Depends");
                  Global  : constant Libadalang.Analysis.Expr :=
                    Generic_Contract (Decl, "Global");
               begin
                  if not Libadalang.Analysis.Is_Null (Depends) then
                     return From_Depends (Depends);
                  elsif not Libadalang.Analysis.Is_Null (Global) then
                     return From_Global (Decl, Global);
                  end if;
               end;
               return Unknown
                 ("the dependencies of the generic instance " & Name &
                  " are not followed");
            end;

         when Libadalang.Common.Ada_Subp_Decl
            | Libadalang.Common.Ada_Generic_Subp_Internal
            | Libadalang.Common.Ada_Subp_Body
            | Libadalang.Common.Ada_Expr_Function
            | Libadalang.Common.Ada_Subp_Body_Stub
            | Libadalang.Common.Ada_Formal_Subp_Decl =>
            declare
               Next : constant Libadalang.Analysis.Ada_Node :=
                 (if Decl.Kind in Libadalang.Common.Ada_Subp_Body
                       | Libadalang.Common.Ada_Expr_Function
                  then Decl.As_Ada_Node
                  elsif Decl.Kind in Libadalang.Common.Ada_Formal_Subp_Decl
                  then Libadalang.Analysis.No_Ada_Node
                  elsif Decl.Kind = Libadalang.Common.Ada_Subp_Body_Stub
                  then Decl.P_Next_Part_For_Decl.As_Ada_Node
                  else Decl.P_Body_Part_For_Decl.As_Ada_Node);
               Is_Body : constant Boolean :=
                 not Libadalang.Analysis.Is_Null (Next)
                 and then Next.Kind in Libadalang.Common.Ada_Subp_Body
                   | Libadalang.Common.Ada_Expr_Function;

               --  The refinement is the caller's business only inside the
               --  package body that holds the callee's body.
               function Refinement_Visible return Boolean is
                  Scope : Libadalang.Analysis.Ada_Node := Next.Parent;
               begin
                  while not Libadalang.Analysis.Is_Null (Scope) loop
                     if Scope.Kind = Libadalang.Common.Ada_Package_Body then
                        return Within (Caller, Scope);
                     end if;
                     Scope := Scope.Parent;
                  end loop;
                  return False;
               end Refinement_Visible;

               Refined_Depends : constant Libadalang.Analysis.Expr :=
                 (if Is_Body
                  then Aspect_Expression
                         (Next.As_Basic_Decl, "Refined_Depends")
                  else Libadalang.Analysis.No_Expr);
               Refined_Global  : constant Libadalang.Analysis.Expr :=
                 (if Is_Body
                  then Aspect_Expression
                         (Next.As_Basic_Decl, "Refined_Global")
                  else Libadalang.Analysis.No_Expr);
               Depends : constant Libadalang.Analysis.Expr :=
                 Contract (Decl, "Depends");
               Global  : constant Libadalang.Analysis.Expr :=
                 Contract (Decl, "Global");
            begin
               if not Libadalang.Analysis.Is_Null (Refined_Depends)
                 and then Refinement_Visible
               then
                  return From_Depends (Refined_Depends);
               elsif not Libadalang.Analysis.Is_Null (Depends) then
                  return From_Depends (Depends);
               elsif Is_Body
                 and then SPARK_Readiness.Effective_SPARK_Enabled
                            (Next.As_Basic_Decl)
               then
                  declare
                     Worked_Out : constant Flow_Summary :=
                       From_Body (Next.As_Base_Subp_Body);
                  begin
                     if Worked_Out.Known then
                        return Worked_Out;
                     end if;
                  end;
               end if;

               if not Libadalang.Analysis.Is_Null (Refined_Global)
                 and then Refinement_Visible
               then
                  return From_Global (Decl, Refined_Global);
               elsif not Libadalang.Analysis.Is_Null (Global) then
                  return From_Global (Decl, Global);
               elsif Is_Body then
                  --  What the body touches, each output from every input.
                  declare
                     Touched : constant Effects :=
                       Callee_Effects (Decl, Caller);
                  begin
                     if Touched.Complete then
                        return From_Effects (Decl, Touched);
                     end if;
                  end;
               elsif Decl.Kind not in Libadalang.Common.Ada_Formal_Subp_Decl
                 and then Is_Pure_Unit (Decl)
               then
                  return From_Global (Decl, Libadalang.Analysis.No_Expr);
               elsif Is_Intrinsic (Decl) then
                  return (All_Inputs => True, others => <>);
               elsif Decl.Kind in Libadalang.Common.Ada_Formal_Subp_Decl then
                  if Actuals_Keep_To_Themselves (Decl, 0) then
                     return From_Global (Decl, Libadalang.Analysis.No_Expr);
                  end if;
                  return Unknown
                    (Name & " is a generic formal subprogram with no " &
                     "Global aspect");
               end if;
               return Unknown
                 ("the dependencies of " & Name & " are not known");
            end;

         when others =>
            return Unknown
              ("the dependencies of the call to " & Name &
               " are not known");
      end case;
   exception
      when Exc : others =>
         return Unknown
           ("the call to " & Name & " was not resolved: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Callee_Summary;

   --  The constituents of the state abstraction Key, where its refinement
   --  is visible from the body being analyzed; empty otherwise.
   function Visible_Constituents (Key : String) return Key_Sets.Set is
      Result : Key_Sets.Set;
      Name   : constant Libadalang.Analysis.Defining_Name := Name_Of (Key);
      Scope  : Libadalang.Analysis.Ada_Node;

      procedure Add (Node : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
            Add (Node.As_Paren_Expr.F_Expr);
         elsif Node.Kind in Libadalang.Common.Ada_Base_Aggregate then
            for Item of Node.As_Base_Aggregate.F_Assocs loop
               if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
                  Add (Item.As_Aggregate_Assoc.F_R_Expr);
               end if;
            end loop;
         elsif Node.Kind in Libadalang.Common.Ada_Identifier
                 | Libadalang.Common.Ada_Dotted_Name
         then
            declare
               Site : constant Libadalang.Analysis.Defining_Name :=
                 Node.As_Name.P_Referenced_Defining_Name;
            begin
               if not Libadalang.Analysis.Is_Null (Site) then
                  Result.Include (Object_Key (Site));
               end if;
            end;
         end if;
      end Add;
   begin
      if Libadalang.Analysis.Is_Null (Name)
        or else Name.P_Basic_Decl.Kind /=
          Libadalang.Common.Ada_Abstract_State_Decl
        or else Libadalang.Analysis.Is_Null (Analyzed)
      then
         return Result;
      end if;
      Scope := Analyzed.Parent;
      while not Libadalang.Analysis.Is_Null (Scope) loop
         if Scope.Kind = Libadalang.Common.Ada_Package_Body then
            declare
               Refined : constant Libadalang.Analysis.Expr :=
                 Aspect_Expression (Scope.As_Basic_Decl, "Refined_State");
            begin
               if not Libadalang.Analysis.Is_Null (Refined)
                 and then Refined.Kind in Libadalang.Common.Ada_Base_Aggregate
               then
                  for Item of Refined.As_Base_Aggregate.F_Assocs loop
                     if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc
                       and then Item.As_Aggregate_Assoc.F_Designators
                                  .Children_Count = 1
                     then
                        declare
                           State : constant Libadalang.Analysis.Defining_Name
                             := Item.As_Aggregate_Assoc.F_Designators.Child (1)
                                  .As_Name.P_Referenced_Defining_Name;
                        begin
                           if not Libadalang.Analysis.Is_Null (State)
                             and then Object_Key (State) = Key
                           then
                              Add (Item.As_Aggregate_Assoc.F_R_Expr);
                           end if;
                        end;
                     end if;
                  end loop;
               end if;
            end;
         end if;
         Scope := Scope.Parent;
      end loop;
      return Result;
   exception
      when others =>
         return Key_Sets.Empty_Set;
   end Visible_Constituents;

   --  The object that Key stands for in the body being analyzed: Key, or,
   --  when it is a constituent of a state abstraction whose refinement that
   --  body does not see, the state (or the state that one is part of). A
   --  callee's summary worked out from its body names what the body sees;
   --  the caller holds the values of what it sees.
   function Caller_View (Key : String) return String is
      Current : Unbounded_String := To_Unbounded_String (Key);
   begin
      for Step in 1 .. 8 loop
         declare
            Name  : constant Libadalang.Analysis.Defining_Name :=
              Name_Of (To_String (Current));
            State : Libadalang.Analysis.Defining_Name;
         begin
            exit when Libadalang.Analysis.Is_Null (Name);
            State := Encapsulating_State (Name, Name);
            exit when Libadalang.Analysis.Is_Null (State);
            exit when Visible_Constituents (Object_Key (State)).Contains
                        (To_String (Current));
            Current := To_Unbounded_String (Object_Key (State));
         end;
      end loop;
      return To_String (Current);
   exception
      when others =>
         return To_String (Current);
   end Caller_View;

   --  The properties of an external object or state that matter to its
   --  flows: a read may see a value written from outside (Async_Writers),
   --  a read is a write (Effective_Reads), each write is seen from outside
   --  (Async_Readers, Effective_Writes).
   type Volatility is record
      Async_Writers    : Boolean := False;
      Effective_Reads  : Boolean := False;
      --  Each write is seen from outside: what was written before stays
      --  part of what the object stands for (Effective_Writes).
      Seen_Writes      : Boolean := False;
   end record;

   function Volatility_Of (Key : String) return Volatility is
      Name : constant Libadalang.Analysis.Defining_Name := Name_Of (Key);
      Decl : Libadalang.Analysis.Basic_Decl;

      function Has (Aspect : String) return Boolean
      is (Decl.P_Has_Aspect
            (Langkit_Support.Text.To_Unbounded_Text
               (Langkit_Support.Text.To_Text (Aspect))));
   begin
      if Libadalang.Analysis.Is_Null (Name) then
         return (others => False);
      end if;
      Decl := Name.P_Basic_Decl;
      if Decl.Kind = Libadalang.Common.Ada_Abstract_State_Decl then
         declare
            Text : constant String := Lower_Text (Decl);
            function Says (Part : String) return Boolean
            is (Ada.Strings.Fixed.Index (Text, Part) /= 0);
         begin
            if not Says ("external") then
               return (others => False);
            elsif not (Says ("async-writers") or else Says ("async-readers")
                       or else Says ("effective-reads")
                       or else Says ("effective-writes"))
            then
               return (others => True);
            end if;
            return (Async_Writers   => Says ("async-writers"),
                    Effective_Reads => Says ("effective-reads"),
                    Seen_Writes     => Says ("effective-writes"));
         end;
      elsif Decl.Kind = Libadalang.Common.Ada_Object_Decl then
         declare
            AW : constant Boolean := Has ("Async_Writers");
            AR : constant Boolean := Has ("Async_Readers");
            ER : constant Boolean := Has ("Effective_Reads");
            EW : constant Boolean := Has ("Effective_Writes");
         begin
            if (Has ("Volatile") or else Has ("Atomic"))
              and then not (AW or else AR or else ER or else EW)
            then
               return (others => True);
            end if;
            pragma Unreferenced (AR);
            return (Async_Writers => AW, Effective_Reads => ER,
                    Seen_Writes => EW);
         end;
      end if;
      return (others => False);
   exception
      when others =>
         return (others => True);
   end Volatility_Of;

   ------------------------------------------------------------------
   --  Bodies
   ------------------------------------------------------------------

   --  True when Decl is an operation of a protected object, which reads and
   --  writes that object, an operand the call does not show.
   function Is_Protected_Operation
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Scope : Libadalang.Analysis.Ada_Node := Decl.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Scope) loop
         if Scope.Kind in Libadalang.Common.Ada_Protected_Type_Decl
             | Libadalang.Common.Ada_Single_Protected_Decl
             | Libadalang.Common.Ada_Protected_Body
         then
            return True;
         end if;
         Scope := Scope.Parent;
      end loop;
      return False;
   end Is_Protected_Operation;

   --  True when Statement is ghost code, which changes no value outside it.
   function Is_Ghost (Statement : Libadalang.Analysis.Stmt'Class)
     return Boolean is
   begin
      return Statement.P_Is_Ghost_Code;
   exception
      when others =>
         return False;
   end Is_Ghost;

   type Loop_Frame is record
      Label        : Unbounded_String;
      Exit_Control : Key_Sets.Set;
      Exit_State   : Flow_State := Dead;
   end record;

   package Loop_Frame_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Loop_Frame);

   function Analyze_Body
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class)
      return Body_Flows
   is
      Flows   : Body_Flows;
      --  The conditions under which a return was met: what follows it
      --  runs only when it was not taken.
      Sticky  : Key_Sets.Set;
      Returns : Flow_State := Dead;
      Frames  : Loop_Frame_Vectors.Vector;
      --  Where the bounds of a local array come from.
      Bounds_Of_Local : Key_Set_Maps.Map;
      --  What the name of a renamed part was evaluated from.
      Renamed : Key_Set_Maps.Map;
      --  Where the bounds of a local subtype come from.
      Type_Bounds : Key_Set_Maps.Map;
      --  The containers of the loop parameters of "for ... of" loops.
      Containers : Node_Maps.Map;
      --  Objects read this statement whose read is a write.
      Read_Writes : Key_Sets.Set;

      procedure Give_Up (Reason : String) is
      begin
         if Flows.Known then
            Flows.Known := False;
            Flows.Reason := To_Unbounded_String (Reason);
         end if;
      end Give_Up;

      function Under (Control : Key_Sets.Set) return Key_Sets.Set
      is (Key_Sets.Union (Control, Sticky));

      procedure Join_Into (Into : in out Flow_State; Source : Flow_State) is
         Done : Boolean := True;
      begin
         Join (Into, Source, Done);
         if not Done then
            Give_Up ("an object was split into components on one path only");
         end if;
      end Join_Into;

      function Deps
        (Node : Libadalang.Analysis.Ada_Node'Class;
         S    : Flow_State) return Key_Sets.Set;

      --  The bounds of the array Root.
      function Bounds (Root : String) return Key_Sets.Set is
         Name : constant Libadalang.Analysis.Defining_Name := Name_Of (Root);
      begin
         if Bounds_Of_Local.Contains (Root) then
            return Bounds_Of_Local.Element (Root);
         elsif Is_Local_Key (Root) then
            return Key_Sets.Empty_Set;
         elsif Libadalang.Analysis.Is_Null (Name) then
            return Key_Sets.To_Set (Root);
         end if;
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Name.P_Basic_Decl;
            Of_Type : constant Libadalang.Analysis.Type_Expr :=
              (case Decl.Kind is
                  when Libadalang.Common.Ada_Object_Decl =>
                    Decl.As_Object_Decl.F_Type_Expr,
                  when Libadalang.Common.Ada_Param_Spec =>
                    Decl.As_Param_Spec.F_Type_Expr,
                  when others => Libadalang.Analysis.No_Type_Expr);
         begin
            if not Libadalang.Analysis.Is_Null (Of_Type)
              and then (Of_Type.P_Is_Statically_Constrained
                        or else Fixed_Bounds (Of_Type))
            then
               return Key_Sets.Empty_Set;
            end if;
            return Key_Sets.To_Set (Root);
         end;
      exception
         when others =>
            return Key_Sets.To_Set (Root);
      end Bounds;

      --  Where the name Node leads: the path of the object or component it
      --  denotes, Exact when it denotes that whole path and not only a part
      --  of it, and Extra, what the indexes and renamings on the way were
      --  evaluated from.
      procedure Locate
        (Node  : Libadalang.Analysis.Ada_Node'Class;
         S     : Flow_State;
         Path  : out Unbounded_String;
         Exact : out Boolean;
         Extra : in out Key_Sets.Set;
         Found : out Boolean)
      is
      begin
         Found := False;
         Exact := False;
         Path := Null_Unbounded_String;
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         end if;

         case Node.Kind is
            when Libadalang.Common.Ada_Identifier
               | Libadalang.Common.Ada_Dotted_Name =>
               declare
                  Decl : constant Libadalang.Analysis.Basic_Decl :=
                    Node.As_Name.P_Referenced_Decl;
               begin
                  if Libadalang.Analysis.Is_Null (Decl) then
                     return;
                  end if;
                  case Decl.Kind is
                     when Libadalang.Common.Ada_Object_Decl
                        | Libadalang.Common.Ada_Extended_Return_Stmt_Object_Decl
                        | Libadalang.Common.Ada_Param_Spec
                        | Libadalang.Common.Ada_For_Loop_Var_Decl
                        | Libadalang.Common.Ada_Abstract_State_Decl =>
                        declare
                           Site : constant Libadalang.Analysis.Defining_Name
                             := Node.As_Name.P_Referenced_Defining_Name;
                           Key  : constant String := Object_Key (Site);
                        begin
                           if Decl.Kind = Libadalang.Common.Ada_Object_Decl
                             and then not Libadalang.Analysis.Is_Null
                               (Decl.As_Object_Decl.F_Renaming_Clause)
                           then
                              if Renamed.Contains (Key) then
                                 Extra.Union (Renamed.Element (Key));
                              end if;
                              Locate
                                (Decl.As_Object_Decl.F_Renaming_Clause
                                   .F_Renamed_Object,
                                 S, Path, Exact, Extra, Found);
                              Exact := False;
                              return;
                           elsif Containers.Contains (Key) then
                              Locate
                                (Containers.Element (Key).Node, S, Path,
                                 Exact, Extra, Found);
                              Exact := False;
                              return;
                           end if;
                           Path := To_Unbounded_String (Key);
                           Exact := True;
                           Found := True;
                        end;
                     when Libadalang.Common.Ada_Component_Decl
                        | Libadalang.Common.Ada_Discriminant_Spec =>
                        if Node.Kind = Libadalang.Common.Ada_Dotted_Name then
                           Locate
                             (Node.As_Dotted_Name.F_Prefix, S, Path, Exact,
                              Extra, Found);
                           if Found and then Exact then
                              Append
                                (Path,
                                 Component_Mark &
                                   Lower_Text
                                     (Node.As_Dotted_Name.F_Suffix));
                           end if;
                        end if;
                     when others =>
                        null;
                  end case;
               end;

            when Libadalang.Common.Ada_Call_Expr =>
               case Node.As_Call_Expr.P_Kind is
                  when Libadalang.Common.Array_Index
                     | Libadalang.Common.Array_Slice =>
                     Locate
                       (Node.As_Call_Expr.F_Name, S, Path, Exact, Extra,
                        Found);
                     Extra.Union (Deps (Node.As_Call_Expr.F_Suffix, S));
                     Exact := False;
                  when Libadalang.Common.Type_Conversion =>
                     declare
                        Suffix : constant Libadalang.Analysis.Ada_Node :=
                          Node.As_Call_Expr.F_Suffix;
                     begin
                        if Suffix.Kind in Libadalang.Common.Ada_Expr then
                           Locate (Suffix, S, Path, Exact, Extra, Found);
                        elsif Suffix.Children_Count = 1
                          and then Suffix.Child (1).Kind =
                            Libadalang.Common.Ada_Param_Assoc
                        then
                           Locate
                             (Suffix.Child (1).As_Param_Assoc.F_R_Expr, S,
                              Path, Exact, Extra, Found);
                        end if;
                     end;
                  when others =>
                     null;
               end case;

            when Libadalang.Common.Ada_Explicit_Deref =>
               Locate
                 (Node.As_Explicit_Deref.F_Prefix, S, Path, Exact, Extra,
                  Found);
               Exact := False;

            when Libadalang.Common.Ada_Paren_Expr =>
               Locate
                 (Node.As_Paren_Expr.F_Expr, S, Path, Exact, Extra, Found);

            when others =>
               null;
         end case;
      end Locate;

      --  What reading the object or part at Path gives.
      function Read (S : Flow_State; Path : String) return Key_Sets.Set is
         Root   : constant String := Root_Of (Path);
         Result : Key_Sets.Set := Value (S, Path);
      begin
         --  The value of a whole array is its bounds too.
         if Path = Root and then Is_Array_Object (Root) then
            Result.Union (Bounds (Root));
         end if;
         if not Is_Local_Key (Root) then
            declare
               Kind : constant Volatility := Volatility_Of (Root);
            begin
               if Kind.Async_Writers then
                  Result.Include (Root);
               end if;
               if Kind.Effective_Reads then
                  Read_Writes.Include (Root);
               end if;
            end;
         end if;
         return Result;
      end Read;

      --  What a call to a function gives, Name being the function's name
      --  and Call the call when it has parameters.
      function Call_Deps
        (Name : Libadalang.Analysis.Name'Class;
         Decl : Libadalang.Analysis.Basic_Decl'Class;
         Call : Libadalang.Analysis.Call_Expr'Class;
         S    : Flow_State) return Key_Sets.Set;

      function Attribute_Deps
        (Node : Libadalang.Analysis.Attribute_Ref'Class;
         S    : Flow_State) return Key_Sets.Set
      is
         Attribute : constant String := Lower_Text (Node.F_Attribute);
         Prefix    : constant Libadalang.Analysis.Name := Node.F_Prefix;
         Result    : Key_Sets.Set;
         Decl      : Libadalang.Analysis.Basic_Decl;
      begin
         if Attribute in "access" | "unchecked-access" | "unrestricted-access"
           | "address" | "read" | "write" | "input" | "output" | "put-image"
         then
            Give_Up ("the attribute " & Attribute & " is not followed");
            return Result;
         elsif Attribute = "result" then
            return Result;
         end if;

         if not Libadalang.Analysis.Is_Null (Node.F_Args) then
            Result.Union (Deps (Node.F_Args, S));
         end if;

         if Prefix.Kind in Libadalang.Common.Ada_Identifier
             | Libadalang.Common.Ada_Dotted_Name
         then
            Decl := Prefix.P_Referenced_Decl;
            if not Libadalang.Analysis.Is_Null (Decl)
              and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
            then
               declare
                  Key : constant String :=
                    Object_Key (Prefix.P_Referenced_Defining_Name);
               begin
                  if Type_Bounds.Contains (Key) then
                     Result.Union (Type_Bounds.Element (Key));
                  end if;
               end;
               return Result;
            end if;
         end if;

         if Attribute in "first" | "last" | "length" | "range" then
            declare
               Path  : Unbounded_String;
               Exact : Boolean;
               Found : Boolean;
               Extra : Key_Sets.Set;
            begin
               Locate (Prefix, S, Path, Exact, Extra, Found);
               if Found then
                  Result.Union (Bounds (Root_Of (To_String (Path))));
                  if To_String (Path) /= Root_Of (To_String (Path))
                    or else not Exact
                  then
                     Result.Union (Extra);
                     Result.Union (Read (S, To_String (Path)));
                  end if;
                  return Result;
               end if;
            end;
         end if;

         Result.Union (Deps (Prefix, S));
         return Result;
      end Attribute_Deps;

      function Deps
        (Node : Libadalang.Analysis.Ada_Node'Class;
         S    : Flow_State) return Key_Sets.Set
      is
         Result : Key_Sets.Set;

         procedure Children_Deps is
         begin
            for Index in 1 .. Node.Children_Count loop
               if not Libadalang.Analysis.Is_Null (Node.Child (Index)) then
                  Result.Union (Deps (Node.Child (Index), S));
               end if;
            end loop;
         end Children_Deps;
      begin
         if Libadalang.Analysis.Is_Null (Node) or else not Flows.Known then
            return Result;
         end if;

         case Node.Kind is
            when Libadalang.Common.Ada_Identifier
               | Libadalang.Common.Ada_Dotted_Name =>
               declare
                  Decl : constant Libadalang.Analysis.Basic_Decl :=
                    Node.As_Name.P_Referenced_Decl;
               begin
                  if Libadalang.Analysis.Is_Null (Decl) then
                     if Node.Kind = Libadalang.Common.Ada_Dotted_Name then
                        Result := Deps (Node.As_Dotted_Name.F_Prefix, S);
                     end if;
                     return Result;
                  end if;

                  case Decl.Kind is
                     when Libadalang.Common.Ada_Object_Decl
                        | Libadalang.Common.Ada_Extended_Return_Stmt_Object_Decl
                        | Libadalang.Common.Ada_Param_Spec
                        | Libadalang.Common.Ada_For_Loop_Var_Decl
                        | Libadalang.Common.Ada_Component_Decl
                        | Libadalang.Common.Ada_Discriminant_Spec =>
                        if Decl.Kind = Libadalang.Common.Ada_Object_Decl
                          and then Is_Not_A_Global
                                     (Node.As_Name
                                        .P_Referenced_Defining_Name)
                        then
                           return Result;
                        end if;
                        declare
                           Path  : Unbounded_String;
                           Exact : Boolean;
                           Found : Boolean;
                        begin
                           Locate (Node, S, Path, Exact, Result, Found);
                           if Found then
                              Result.Union (Read (S, To_String (Path)));
                           elsif Node.Kind = Libadalang.Common.Ada_Dotted_Name
                           then
                              Result.Union
                                (Deps (Node.As_Dotted_Name.F_Prefix, S));
                           end if;
                        end;

                     when Libadalang.Common.Ada_Basic_Subp_Decl
                        | Libadalang.Common.Ada_Base_Subp_Body
                        | Libadalang.Common.Ada_Subp_Body_Stub
                        | Libadalang.Common.Ada_Generic_Subp_Instantiation =>
                        if Decl.Kind = Libadalang.Common.Ada_Enum_Literal_Decl
                        then
                           return Result;
                        elsif Node.As_Name.P_Is_Call then
                           Result := Call_Deps
                             (Node.As_Name, Decl,
                              Libadalang.Analysis.No_Call_Expr, S);
                        end if;

                     when Libadalang.Common.Ada_Base_Type_Decl =>
                        declare
                           Key : constant String :=
                             Object_Key
                               (Node.As_Name.P_Referenced_Defining_Name);
                        begin
                           if Type_Bounds.Contains (Key) then
                              Result := Type_Bounds.Element (Key);
                           end if;
                        end;

                     when others =>
                        if Node.Kind = Libadalang.Common.Ada_Dotted_Name then
                           Result := Deps (Node.As_Dotted_Name.F_Prefix, S);
                        end if;
                  end case;
               end;

            when Libadalang.Common.Ada_Call_Expr =>
               declare
                  Call : constant Libadalang.Analysis.Call_Expr :=
                    Node.As_Call_Expr;
               begin
                  case Call.P_Kind is
                     when Libadalang.Common.Array_Index
                        | Libadalang.Common.Array_Slice =>
                        declare
                           Path  : Unbounded_String;
                           Exact : Boolean;
                           Found : Boolean;
                        begin
                           Locate (Node, S, Path, Exact, Result, Found);
                           if Found then
                              Result.Union (Read (S, To_String (Path)));
                           else
                              Result.Union (Deps (Call.F_Name, S));
                              Result.Union (Deps (Call.F_Suffix, S));
                           end if;
                        end;
                     when Libadalang.Common.Type_Conversion =>
                        Result := Deps (Call.F_Suffix, S);
                     when Libadalang.Common.Call =>
                        Result := Call_Deps
                          (Call.F_Name, Call.F_Name.P_Referenced_Decl, Call,
                           S);
                     when others =>
                        Give_Up ("a call to an entry family is not followed");
                  end case;
               end;

            when Libadalang.Common.Ada_Attribute_Ref =>
               Result := Attribute_Deps (Node.As_Attribute_Ref, S);

            when Libadalang.Common.Ada_Bin_Op
               | Libadalang.Common.Ada_Un_Op =>
               declare
                  Operator : constant Libadalang.Analysis.Name :=
                    (if Node.Kind = Libadalang.Common.Ada_Un_Op
                     then Node.As_Un_Op.F_Op.As_Name
                     else Node.As_Bin_Op.F_Op.As_Name);
                  Decl : constant Libadalang.Analysis.Basic_Decl :=
                    Operator.P_Referenced_Decl;
               begin
                  Children_Deps;
                  if not Libadalang.Analysis.Is_Null (Decl)
                    and then Decl.Kind in Libadalang.Common.Ada_Basic_Subp_Decl
                      | Libadalang.Common.Ada_Base_Subp_Body
                    and then Decl.Kind /=
                      Libadalang.Common.Ada_Synthetic_Subp_Decl
                  then
                     --  A user-defined operator: what it reads besides its
                     --  operands.
                     declare
                        Summary : constant Flow_Summary :=
                          Callee_Summary (Decl, Subprogram);
                     begin
                        if not Summary.Known then
                           Give_Up (To_String (Summary.Reason));
                        elsif not Summary.All_Inputs
                          and then Summary.Flows.Contains (Result_Key)
                        then
                           for Input of Summary.Flows.Element (Result_Key) loop
                              if not Formals_Of (Decl).Contains (Input) then
                                 Result.Union (Read (S, Caller_View (Input)));
                              end if;
                           end loop;
                        end if;
                     end;
                  end if;
               end;

            when Libadalang.Common.Ada_Param_Assoc =>
               Result := Deps (Node.As_Param_Assoc.F_R_Expr, S);

            when Libadalang.Common.Ada_Defining_Name  --  adalang-analyzer: ignore Null_Case_Alternative
               | Libadalang.Common.Ada_Raise_Expr
               | Libadalang.Common.Ada_End_Name =>
               --  Nothing that holds a value.
               null;

            when Libadalang.Common.Ada_Target_Name
               | Libadalang.Common.Ada_Decl_Expr =>
               Give_Up ("this expression form is not followed");

            when others =>
               Children_Deps;
         end case;
         return Result;
      exception
         when Exc : others =>
            Give_Up
              ("an expression was not resolved: " &
               Ada.Exceptions.Exception_Message (Exc));
            return Result;
      end Deps;

      --  What the input Input of a callee holds at a call, given the
      --  actuals of the call.
      function Input_Value
        (Input   : String;
         Formals : Key_Sets.Set;
         Actuals : Libadalang.Analysis.Param_Actual_Array;
         S       : Flow_State) return Key_Sets.Set
      is
         Result : Key_Sets.Set;
      begin
         if Input = Result_Key then
            return Result;
         elsif Is_Formal (Input) and then not Formals.Contains (Input)
           and then not Encloses_Formal (Input, Subprogram)
         then
            Give_Up ("a callee's contract names a formal of another subprogram");
            return Result;
         elsif Formals.Contains (Input) then
            for Pair of Actuals loop
               if Object_Key (Libadalang.Analysis.Param (Pair)) = Input then
                  declare
                     Actual : constant Libadalang.Analysis.Expr :=
                       Libadalang.Analysis.Actual (Pair).As_Expr;
                  begin
                     Result.Union (Deps (Actual, S));
                     if Formal_Mode (Input) = Libadalang.Common.Ada_Mode_Out
                     then
                        declare
                           Path  : Unbounded_String;
                           Exact : Boolean;
                           Found : Boolean;
                        begin
                           Locate (Actual, S, Path, Exact, Result, Found);
                           if Found then
                              Result.Union
                                (Bounds (Root_Of (To_String (Path))));
                           end if;
                        end;
                     end if;
                     return Result;
                  end;
               end if;
            end loop;
            --  Left to its default.
            declare
               Default : constant Libadalang.Analysis.Expr :=
                 Name_Of (Input).P_Basic_Decl.As_Param_Spec.F_Default_Expr;
            begin
               if Libadalang.Analysis.Is_Null (Default) then
                  Give_Up ("a formal of a call has no actual");
               else
                  Result.Union (Deps (Default, S));
               end if;
            end;
            return Result;
         end if;

         --  An object the callee reads: what it holds, or what the
         --  constituents of a state hold.
         if Caller_View (Input) /= Input then
            return Input_Value (Caller_View (Input), Formals, Actuals, S);
         end if;
         declare
            Parts : constant Key_Sets.Set := Visible_Constituents (Input);
         begin
            if Parts.Is_Empty then
               return Read (S, Input);
            end if;
            for Part of Parts loop
               Result.Union (Input_Value (Part, Formals, Actuals, S));
            end loop;
            if S.Values.Contains (Input) then
               Result.Union (S.Values.Element (Input));
            end if;
            return Result;
         end;
      end Input_Value;

      function Call_Deps
        (Name : Libadalang.Analysis.Name'Class;
         Decl : Libadalang.Analysis.Basic_Decl'Class;
         Call : Libadalang.Analysis.Call_Expr'Class;
         S    : Flow_State) return Key_Sets.Set
      is
         Result  : Key_Sets.Set;
         Actuals : constant Libadalang.Analysis.Param_Actual_Array :=
           (if Libadalang.Analysis.Is_Null (Call) then
              (1 .. 0 => <>)
            else Call.P_Call_Params);
      begin
         if Name.Kind = Libadalang.Common.Ada_Explicit_Deref then
            Give_Up ("a call through an access value");
            return Result;
         elsif not Libadalang.Analysis.Is_Null (Decl)
           and then Is_Protected_Operation (Decl)
         then
            Give_Up ("tasking is not followed");
            return Result;
         elsif Name.P_Is_Dispatching_Call then
            Give_Up ("the call to " & Node_Text (Name) & " dispatches");
            return Result;
         end if;

         if Name.Kind = Libadalang.Common.Ada_Dotted_Name
           and then Name.P_Is_Dot_Call
         then
            Result.Union (Deps (Name.As_Dotted_Name.F_Prefix, S));
         end if;

         declare
            Summary : constant Flow_Summary :=
              Callee_Summary (Decl, Subprogram);
         begin
            if not Summary.Known then
               Give_Up (To_String (Summary.Reason));
            elsif Summary.All_Inputs then
               if not Libadalang.Analysis.Is_Null (Call) then
                  Result.Union (Deps (Call.F_Suffix, S));
               end if;
            elsif Summary.Flows.Contains (Result_Key) then
               for Input of Summary.Flows.Element (Result_Key) loop
                  Result.Union (Input_Value (Input, Formals_Of (Decl), Actuals, S));
               end loop;
            end if;
         end;
         return Result;
      end Call_Deps;

      procedure Run_List
        (List    : Libadalang.Analysis.Ada_Node'Class;
         S       : in out Flow_State;
         Control : Key_Sets.Set);

      procedure Run_Decls
        (List    : Libadalang.Analysis.Ada_Node'Class;
         S       : in out Flow_State;
         Control : Key_Sets.Set);

      --  The writes a call statement makes.
      procedure Run_Call
        (Node    : Libadalang.Analysis.Call_Stmt'Class;
         S       : in out Flow_State;
         Control : Key_Sets.Set)
      is
         Target : constant Libadalang.Analysis.Name := Node.F_Call;
         Name   : constant Libadalang.Analysis.Name :=
           (if Target.Kind = Libadalang.Common.Ada_Call_Expr
            then Target.As_Call_Expr.F_Name else Target);
         Actuals : constant Libadalang.Analysis.Param_Actual_Array :=
           (if Target.Kind = Libadalang.Common.Ada_Call_Expr
            then Target.As_Call_Expr.P_Call_Params else (1 .. 0 => <>));
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
         Formals : constant Key_Sets.Set := Formals_Of (Decl);

         type Pending_Write is record
            Path  : Unbounded_String;
            Value : Key_Sets.Set;
            Whole : Boolean;
         end record;
         package Write_Vectors is new Ada.Containers.Vectors
           (Index_Type => Positive, Element_Type => Pending_Write);
         Writes : Write_Vectors.Vector;
      begin
         if Libadalang.Analysis.Is_Null (Decl) then
            Give_Up ("the call " & Node_Text (Name) & " was not resolved");
            return;
         elsif Name.Kind = Libadalang.Common.Ada_Explicit_Deref then
            Give_Up ("a call through an access value");
            return;
         elsif Decl.Kind = Libadalang.Common.Ada_Entry_Decl
           or else Is_Protected_Operation (Decl)
         then
            Give_Up ("tasking is not followed");
            return;
         elsif Decl.P_Has_Aspect
                 (Langkit_Support.Text.To_Unbounded_Text
                    (Langkit_Support.Text.To_Text ("No_Return")))
         then
            --  It does not return: nothing after it runs.
            S.Alive := False;
            return;
         elsif Name.P_Is_Dispatching_Call then
            Give_Up ("the call to " & Node_Text (Name) & " dispatches");
            return;
         elsif Name.Kind = Libadalang.Common.Ada_Dotted_Name
           and then Name.P_Is_Dot_Call
         then
            Give_Up ("a call in prefix notation is not followed");
            return;
         end if;

         declare
            Summary : constant Flow_Summary :=
              Callee_Summary (Decl, Subprogram);
         begin
            if not Summary.Known then
               Give_Up (To_String (Summary.Reason));
               return;
            elsif Summary.All_Inputs then
               Give_Up
                 ("the call to " & Node_Text (Name) & " is not followed");
               return;
            end if;

            for Position in Summary.Flows.Iterate loop
               declare
                  Output : constant String := Key_Set_Maps.Key (Position);
                  Value  : Key_Sets.Set := Under (Control);
                  Done   : Boolean := False;
               begin
                  if Output /= Result_Key and then Output /= Null_Key then
                     for Input of Key_Set_Maps.Element (Position) loop
                        Value.Union (Input_Value (Input, Formals, Actuals, S));
                     end loop;

                     if Is_Formal (Output) and then not Formals.Contains (Output)
                       and then not Encloses_Formal (Output, Subprogram)
                     then
                        Give_Up
                          ("a callee's contract names a formal of another " &
                           "subprogram");
                        return;
                     elsif Formals.Contains (Output) then
                        for Pair of Actuals loop
                           if Object_Key (Libadalang.Analysis.Param (Pair)) =
                             Output
                           then
                              declare
                                 Path  : Unbounded_String;
                                 Exact : Boolean;
                                 Found : Boolean;
                              begin
                                 Locate
                                   (Libadalang.Analysis.Actual (Pair), S,
                                    Path, Exact, Value, Found);
                                 if not Found then
                                    Give_Up
                                      ("what " &
                                       Node_Text
                                         (Libadalang.Analysis.Actual (Pair)) &
                                       " stores into was not told");
                                    return;
                                 end if;
                                 Writes.Append
                                   ((Path => Path, Value => Value,
                                     Whole => Exact));
                                 Done := True;
                              end;
                           end if;
                        end loop;
                        if not Done then
                           Give_Up ("an output formal of a call has no actual");
                           return;
                        end if;
                     elsif Caller_View (Output) /= Output then
                        --  A part of a state the caller does not see into.
                        Writes.Append
                          ((Path  => To_Unbounded_String (Caller_View (Output)),
                            Value => Value,
                            Whole => False));
                     else
                        declare
                           Parts : constant Key_Sets.Set :=
                             Visible_Constituents (Output);
                        begin
                           if Parts.Is_Empty then
                              Writes.Append
                                ((Path  => To_Unbounded_String (Output),
                                  Value => Value,
                                  Whole =>
                                    not Volatility_Of (Output).Seen_Writes));
                           else
                              for Part of Parts loop
                                 Writes.Append
                                   ((Path  => To_Unbounded_String (Part),
                                     Value => Value,
                                     Whole => False));
                              end loop;
                           end if;
                        end;
                     end if;
                  end if;
               end;
            end loop;
         end;

         --  Two outputs that may be the same object, or one a part of the
         --  other: neither replaces what the other leaves.
         for Left in Writes.First_Index .. Writes.Last_Index loop
            for Right in Writes.First_Index .. Writes.Last_Index loop
               if Left /= Right then
                  declare
                     A : constant String := To_String (Writes (Left).Path);
                     B : constant String := To_String (Writes (Right).Path);
                  begin
                     if A = B
                       or else (B'Length > A'Length
                                and then B (B'First .. B'First + A'Length) =
                                  A & Component_Mark)
                       or else (Root_Of (A) = Root_Of (B)
                                and then (not Writes (Left).Whole
                                          or else not Writes (Right).Whole))
                     then
                        Writes (Left).Whole := False;
                        Writes (Right).Whole := False;
                     end if;
                  end;
               end if;
            end loop;
         end loop;

         for Item of Writes loop
            Write (S, To_String (Item.Path), Item.Value, Item.Whole);
         end loop;
      end Run_Call;

      procedure Run_Loop
        (Node    : Libadalang.Analysis.Base_Loop_Stmt'Class;
         Label   : String;
         S       : in out Flow_State;
         Control : Key_Sets.Set)
      is
         Max_Rounds : constant := 64;
         Spec       : constant Libadalang.Analysis.Loop_Spec := Node.F_Spec;
         Head       : Flow_State := S;
         Loop_Ctl   : Key_Sets.Set := Control;
         Index      : Positive;
         Rounds     : Natural := 0;
      begin
         Frames.Append ((Label => To_Unbounded_String (Label), others => <>));
         Index := Frames.Last_Index;

         loop
            Rounds := Rounds + 1;
            if Rounds > Max_Rounds then
               Give_Up ("a loop did not settle");
               exit;
            end if;

            declare
               Scheme : Key_Sets.Set;
               Body_S : Flow_State := Head;
               Body_Control : Key_Sets.Set;
               Next_Head    : Flow_State := Head;
            begin
               if not Libadalang.Analysis.Is_Null (Spec) then
                  if Spec.Kind = Libadalang.Common.Ada_While_Loop_Spec then
                     Scheme := Deps (Spec.As_While_Loop_Spec.F_Expr, Head);
                  elsif Spec.Kind = Libadalang.Common.Ada_For_Loop_Spec then
                     Scheme :=
                       Deps (Spec.As_For_Loop_Spec.F_Iter_Expr, Head);
                     if not Libadalang.Analysis.Is_Null
                              (Spec.As_For_Loop_Spec.F_Iter_Filter)
                     then
                        Scheme.Union
                          (Deps (Spec.As_For_Loop_Spec.F_Iter_Filter, Head));
                     end if;
                  end if;
               end if;
               Body_Control := Key_Sets.Union (Loop_Ctl, Scheme);

               Frames (Index).Exit_Control := Key_Sets.Empty_Set;
               Frames (Index).Exit_State := Dead;

               if not Libadalang.Analysis.Is_Null (Spec)
                 and then Spec.Kind = Libadalang.Common.Ada_For_Loop_Spec
               then
                  declare
                     Var : constant Libadalang.Analysis.Defining_Name :=
                       Spec.As_For_Loop_Spec.F_Var_Decl.F_Id;
                     Key : constant String := Object_Key (Var);
                  begin
                     if Spec.As_For_Loop_Spec.F_Loop_Type.Kind =
                       Libadalang.Common.Ada_Iter_Type_Of
                     then
                        Containers.Include
                          (Key,
                           (Node => Spec.As_For_Loop_Spec.F_Iter_Expr));
                     else
                        Write (Body_S, Key, Under (Body_Control), True);
                     end if;
                  end;
               end if;

               Run_List (Node.F_Stmts, Body_S, Body_Control);
               exit when not Flows.Known;

               Join_Into (Next_Head, Body_S);
               Body_Control.Union (Frames (Index).Exit_Control);
               Body_Control.Union (Sticky);
               exit when Same (Next_Head, Head)
                 and then Key_Sets."=" (Body_Control, Loop_Ctl);
               Head := Next_Head;
               Loop_Ctl := Body_Control;
            end;
         end loop;

         if Libadalang.Analysis.Is_Null (Spec) then
            S := Frames (Index).Exit_State;
         else
            S := Head;
            Join_Into (S, Frames (Index).Exit_State);
         end if;
         Frames.Delete_Last;
      end Run_Loop;

      procedure Run_Return
        (Value   : Key_Sets.Set;
         S       : in out Flow_State;
         Control : Key_Sets.Set) is
      begin
         Flows.Result.Union (Value);
         Flows.Result.Union (Under (Control));
         Join_Into (Returns, S);
         Sticky.Union (Under (Control));
         S.Alive := False;
      end Run_Return;

      procedure Run_Statement
        (Node    : Libadalang.Analysis.Ada_Node'Class;
         S       : in out Flow_State;
         Control : Key_Sets.Set) is
      begin
         if Node.Kind in Libadalang.Common.Ada_Stmt
           and then Is_Ghost (Node.As_Stmt)
         then
            return;
         end if;

         case Node.Kind is
            when Libadalang.Common.Ada_Null_Stmt  --  adalang-analyzer: ignore Null_Case_Alternative
               | Libadalang.Common.Ada_Pragma_Node =>
               --  Changes no value: an assertion is no flow.
               null;

            when Libadalang.Common.Ada_Assign_Stmt =>
               declare
                  Path  : Unbounded_String;
                  Exact : Boolean;
                  Found : Boolean;
                  Value : Key_Sets.Set :=
                    Deps (Node.As_Assign_Stmt.F_Expr, S);
               begin
                  Locate
                    (Node.As_Assign_Stmt.F_Dest, S, Path, Exact, Value,
                     Found);
                  if not Found then
                     Give_Up
                       ("what " & Node_Text (Node.As_Assign_Stmt.F_Dest) &
                        " stores into was not told");
                     return;
                  end if;
                  Value.Union (Under (Control));
                  Write
                    (S, To_String (Path), Value,
                     Exact
                     and then not Volatility_Of
                                    (Root_Of (To_String (Path))).Seen_Writes);
               end;

            when Libadalang.Common.Ada_Call_Stmt =>
               Run_Call (Node.As_Call_Stmt, S, Control);

            when Libadalang.Common.Ada_If_Stmt =>
               declare
                  If_Node    : constant Libadalang.Analysis.If_Stmt :=
                    Node.As_If_Stmt;
                  Before     : constant Flow_State := S;
                  Conditions : Key_Sets.Set :=
                    Deps (If_Node.F_Cond_Expr, Before);
                  After      : Flow_State := Dead;
                  Branch     : Flow_State := Before;
               begin
                  Run_List
                    (If_Node.F_Then_Stmts, Branch,
                     Key_Sets.Union (Control, Conditions));
                  Join_Into (After, Branch);
                  for Alternative of If_Node.F_Alternatives loop
                     Conditions.Union
                       (Deps (Alternative.F_Cond_Expr, Before));
                     Branch := Before;
                     Run_List
                       (Alternative.F_Stmts, Branch,
                        Key_Sets.Union (Control, Conditions));
                     Join_Into (After, Branch);
                  end loop;
                  Branch := Before;
                  if not Libadalang.Analysis.Is_Null (If_Node.F_Else_Part)
                  then
                     Run_List
                       (If_Node.F_Else_Part.F_Stmts, Branch,
                        Key_Sets.Union (Control, Conditions));
                  end if;
                  Join_Into (After, Branch);
                  S := After;
               end;

            when Libadalang.Common.Ada_Case_Stmt =>
               declare
                  Before   : constant Flow_State := S;
                  Selector : constant Key_Sets.Set :=
                    Deps (Node.As_Case_Stmt.F_Expr, Before);
                  After    : Flow_State := Dead;
               begin
                  for Alternative of Node.As_Case_Stmt.F_Alternatives loop
                     declare
                        Branch : Flow_State := Before;
                     begin
                        Run_List
                          (Alternative.F_Stmts, Branch,
                           Key_Sets.Union (Control, Selector));
                        Join_Into (After, Branch);
                     end;
                  end loop;
                  S := After;
               end;

            when Libadalang.Common.Ada_Base_Loop_Stmt =>
               Run_Loop (Node.As_Base_Loop_Stmt, "", S, Control);

            when Libadalang.Common.Ada_Named_Stmt =>
               declare
                  Inner : constant Libadalang.Analysis.Composite_Stmt :=
                    Node.As_Named_Stmt.F_Stmt;
               begin
                  if Inner.Kind in Libadalang.Common.Ada_Base_Loop_Stmt then
                     Run_Loop
                       (Inner.As_Base_Loop_Stmt,
                        Lower_Text (Node.As_Named_Stmt.F_Decl.F_Name), S,
                        Control);
                  else
                     Run_Statement (Inner, S, Control);
                  end if;
               end;

            when Libadalang.Common.Ada_Exit_Stmt =>
               declare
                  Exit_Node : constant Libadalang.Analysis.Exit_Stmt :=
                    Node.As_Exit_Stmt;
                  Target    : Natural := 0;
                  Condition : Key_Sets.Set := Under (Control);
               begin
                  if Libadalang.Analysis.Is_Null (Exit_Node.F_Loop_Name) then
                     Target := Frames.Last_Index;
                  else
                     for Index in reverse
                       Frames.First_Index .. Frames.Last_Index
                     loop
                        if To_String (Frames (Index).Label) =
                          Lower_Text (Exit_Node.F_Loop_Name)
                        then
                           Target := Index;
                           exit;
                        end if;
                     end loop;
                  end if;
                  if Target = 0 then
                     Give_Up ("an exit statement was not matched to a loop");
                     return;
                  end if;
                  if not Libadalang.Analysis.Is_Null (Exit_Node.F_Cond_Expr)
                  then
                     Condition.Union (Deps (Exit_Node.F_Cond_Expr, S));
                  end if;
                  for Index in Target .. Frames.Last_Index loop
                     Frames (Index).Exit_Control.Union (Condition);
                  end loop;
                  declare
                     Leaving : Flow_State := Frames (Target).Exit_State;
                  begin
                     Join_Into (Leaving, S);
                     Frames (Target).Exit_State := Leaving;
                  end;
                  if Libadalang.Analysis.Is_Null (Exit_Node.F_Cond_Expr) then
                     S.Alive := False;
                  end if;
               end;

            when Libadalang.Common.Ada_Return_Stmt =>
               Run_Return
                 (Deps (Node.As_Return_Stmt.F_Return_Expr, S), S, Control);

            when Libadalang.Common.Ada_Extended_Return_Stmt =>
               declare
                  Object : constant Libadalang.Analysis.Object_Decl :=
                    Node.As_Extended_Return_Stmt.F_Decl.As_Object_Decl;
                  Value  : Key_Sets.Set;
               begin
                  Run_Decls (Object, S, Control);
                  if Node.As_Extended_Return_Stmt.F_Stmts.F_Exceptions
                       .Children_Count > 0
                  then
                     Give_Up ("an exception handler is not followed");
                     return;
                  end if;
                  Run_List
                    (Node.As_Extended_Return_Stmt.F_Stmts.F_Stmts, S,
                     Control);
                  if S.Alive then
                     for Id of Object.F_Ids loop
                        Value.Union (Read (S, Object_Key (Id)));
                     end loop;
                     Run_Return (Value, S, Control);
                  end if;
               end;

            when Libadalang.Common.Ada_Raise_Stmt =>
               S.Alive := False;

            when Libadalang.Common.Ada_Decl_Block
               | Libadalang.Common.Ada_Begin_Block =>
               declare
                  Handled : constant Libadalang.Analysis.Handled_Stmts :=
                    (if Node.Kind = Libadalang.Common.Ada_Decl_Block
                     then Node.As_Decl_Block.F_Stmts
                     else Node.As_Begin_Block.F_Stmts);
               begin
                  if Handled.F_Exceptions.Children_Count > 0 then
                     Give_Up ("an exception handler is not followed");
                     return;
                  end if;
                  if Node.Kind = Libadalang.Common.Ada_Decl_Block then
                     Run_Decls
                       (Node.As_Decl_Block.F_Decls.F_Decls, S, Control);
                  end if;
                  Run_List (Handled.F_Stmts, S, Control);
               end;

            when Libadalang.Common.Ada_Simple_Decl_Stmt =>
               Run_Decls (Node.As_Simple_Decl_Stmt.F_Decl, S, Control);

            when others =>
               Give_Up
                 ("a " & Libadalang.Common.Ada_Node_Kind_Type'Image
                           (Node.Kind) & " is not followed");
         end case;

         --  What was read that a read writes.
         if not Read_Writes.Is_Empty and then S.Alive then
            for Root of Read_Writes loop
               Write (S, Root, Key_Sets.Union (Value (S, Root),
                                                Under (Control)), False);
            end loop;
            Read_Writes.Clear;
         end if;
      exception
         when Exc : others =>
            Give_Up
              ("a statement was not resolved: " &
               Ada.Exceptions.Exception_Message (Exc));
      end Run_Statement;

      procedure Run_List
        (List    : Libadalang.Analysis.Ada_Node'Class;
         S       : in out Flow_State;
         Control : Key_Sets.Set) is
      begin
         if Libadalang.Analysis.Is_Null (List) then
            return;
         end if;
         for Index in 1 .. List.Children_Count loop
            exit when not S.Alive or else not Flows.Known;
            if not Libadalang.Analysis.Is_Null (List.Child (Index)) then
               Run_Statement (List.Child (Index), S, Control);
            end if;
         end loop;
      end Run_List;

      procedure Declare_Object
        (Decl    : Libadalang.Analysis.Object_Decl'Class;
         S       : in out Flow_State;
         Control : Key_Sets.Set) is
      begin
         for Id of Decl.F_Ids loop
            if Id.P_Is_Ghost_Code then
               return;
            end if;
         end loop;

         if not Libadalang.Analysis.Is_Null (Decl.F_Renaming_Clause) then
            declare
               Path  : Unbounded_String;
               Exact : Boolean;
               Found : Boolean;
               Extra : Key_Sets.Set := Under (Control);
            begin
               Locate
                 (Decl.F_Renaming_Clause.F_Renamed_Object, S, Path, Exact,
                  Extra, Found);
               for Id of Decl.F_Ids loop
                  Renamed.Include (Object_Key (Id), Extra);
               end loop;
            end;
            return;
         end if;

         declare
            Value : Key_Sets.Set;
            Shape : Key_Sets.Set;
         begin
            if not Libadalang.Analysis.Is_Null (Decl.F_Default_Expr) then
               Value := Deps (Decl.F_Default_Expr, S);
               Value.Union (Under (Control));
            end if;
            if not Libadalang.Analysis.Is_Null (Decl.F_Type_Expr)
              and then not Decl.F_Type_Expr.P_Is_Statically_Constrained
            then
               Shape := Deps (Decl.F_Type_Expr, S);
               Shape.Union (Value);
               Shape.Union (Under (Control));
            end if;
            for Id of Decl.F_Ids loop
               declare
                  Key : constant String := Object_Key (Id);
               begin
                  Write (S, Key, Value, True);
                  Bounds_Of_Local.Include (Key, Shape);
               end;
            end loop;
         end;
      end Declare_Object;

      procedure Run_Decls
        (List    : Libadalang.Analysis.Ada_Node'Class;
         S       : in out Flow_State;
         Control : Key_Sets.Set)
      is
         procedure One (Item : Libadalang.Analysis.Ada_Node'Class) is
         begin
            case Item.Kind is
               when Libadalang.Common.Ada_Object_Decl
                  | Libadalang.Common.Ada_Extended_Return_Stmt_Object_Decl =>
                  Declare_Object (Item.As_Object_Decl, S, Control);

               when Libadalang.Common.Ada_Subtype_Decl
                  | Libadalang.Common.Ada_Concrete_Type_Decl =>
                  declare
                     Shape : Key_Sets.Set := Under (Control);
                  begin
                     for Index in 1 .. Item.Children_Count loop
                        if not Libadalang.Analysis.Is_Null (Item.Child (Index))
                        then
                           Shape.Union (Deps (Item.Child (Index), S));
                        end if;
                     end loop;
                     Type_Bounds.Include
                       (Object_Key (Item.As_Basic_Decl.P_Defining_Name),
                        Shape);
                  end;

               when Libadalang.Common.Ada_Subp_Body  --  adalang-analyzer: ignore Null_Case_Alternative
                  | Libadalang.Common.Ada_Subp_Decl
                  | Libadalang.Common.Ada_Expr_Function
                  | Libadalang.Common.Ada_Null_Subp_Decl
                  | Libadalang.Common.Ada_Abstract_Subp_Decl
                  | Libadalang.Common.Ada_Subp_Renaming_Decl
                  | Libadalang.Common.Ada_Subp_Body_Stub
                  | Libadalang.Common.Ada_Generic_Subp_Decl
                  | Libadalang.Common.Ada_Generic_Subp_Instantiation
                  | Libadalang.Common.Ada_Pragma_Node
                  | Libadalang.Common.Ada_Use_Clause
                  | Libadalang.Common.Ada_Number_Decl
                  | Libadalang.Common.Ada_Exception_Decl
                  | Libadalang.Common.Ada_Package_Renaming_Decl
                  | Libadalang.Common.Ada_Incomplete_Type_Decl
                  | Libadalang.Common.Ada_Attribute_Def_Clause
                  | Libadalang.Common.Ada_Record_Rep_Clause
                  | Libadalang.Common.Ada_Enum_Rep_Clause =>
                  --  Declares no object.
                  null;

               when others =>
                  Give_Up
                    ("a local " &
                     Libadalang.Common.Ada_Node_Kind_Type'Image (Item.Kind) &
                     " is not followed");
            end case;
         end One;
      begin
         if Libadalang.Analysis.Is_Null (List) then
            return;
         elsif List.Kind in Libadalang.Common.Ada_Object_Decl
                 | Libadalang.Common.Ada_Extended_Return_Stmt_Object_Decl
         then
            One (List);
            return;
         end if;
         for Index in 1 .. List.Children_Count loop
            exit when not Flows.Known;
            if not Libadalang.Analysis.Is_Null (List.Child (Index)) then
               One (List.Child (Index));
            end if;
         end loop;
      end Run_Decls;

      Saved : constant Saved_Context := Current_Context;
   begin
      Enter (Subprogram);

      if Subprogram.Kind = Libadalang.Common.Ada_Expr_Function then
         declare
            Start : constant Flow_State := (others => <>);
         begin
            Flows.Result := Deps (Subprogram.As_Expr_Function.F_Expr, Start);
            Flows.Final := Start;
         end;
      elsif Subprogram.Kind = Libadalang.Common.Ada_Subp_Body then
         declare
            Body_Node : constant Libadalang.Analysis.Subp_Body :=
              Subprogram.As_Subp_Body;
            S : Flow_State;
         begin
            if Body_Node.F_Stmts.F_Exceptions.Children_Count > 0 then
               Give_Up ("an exception handler is not followed");
            else
               Run_Decls (Body_Node.F_Decls.F_Decls, S, Key_Sets.Empty_Set);
               Run_List (Body_Node.F_Stmts.F_Stmts, S, Key_Sets.Empty_Set);
               Join_Into (S, Returns);
               Flows.Final := S;
            end if;
         end;
      else
         Give_Up ("this kind of body is not followed");
      end if;

      Restore (Saved);
      return Flows;
   exception
      when Exc : others =>
         Restore (Saved);
         Give_Up
           ("the body was not analyzed: " &
            Ada.Exceptions.Exception_Message (Exc));
         return Flows;
   end Analyze_Body;

   ------------------------------------------------------------------
   --  The flow-dependencies obligation
   ------------------------------------------------------------------

   procedure Check_Depends
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class;
      Depends    : Libadalang.Analysis.Expr'Class;
      Report     : not null access procedure
        (Kind : Mismatch_Kind; Output, Input : String))
   is
      Listed : constant Dependency_Contract := Parse_Depends (Depends);

      --  The objects the Global aspect of the body lists as Proof_In.
      Proof_Only : Key_Sets.Set;

      --  The name of the aspect that Key stands for, or is a part of; ""
      --  when none.
      function Up (Key : String) return String is
         Current : Unbounded_String := To_Unbounded_String (Key);
      begin
         for Step in 1 .. 8 loop
            if Listed.Names.Contains (To_String (Current)) then
               return To_String (Current);
            end if;
            declare
               Name  : constant Libadalang.Analysis.Defining_Name :=
                 Name_Of (To_String (Current));
               State : Libadalang.Analysis.Defining_Name;
            begin
               exit when Libadalang.Analysis.Is_Null (Name);
               State := Encapsulating_State (Name, Name);
               exit when Libadalang.Analysis.Is_Null (State);
               Current := To_Unbounded_String (Object_Key (State));
            end;
         end loop;
         return "";
      end Up;

      --  True when Key, or a state abstraction it is part of, is listed as
      --  Proof_In.
      function Proof_In_Only (Key : String) return Boolean is
         Current : Unbounded_String := To_Unbounded_String (Key);
      begin
         for Step in 1 .. 8 loop
            if Proof_Only.Contains (To_String (Current)) then
               return True;
            end if;
            declare
               Name  : constant Libadalang.Analysis.Defining_Name :=
                 Name_Of (To_String (Current));
               State : Libadalang.Analysis.Defining_Name;
            begin
               exit when Libadalang.Analysis.Is_Null (Name);
               State := Encapsulating_State (Name, Name);
               exit when Libadalang.Analysis.Is_Null (State);
               Current := To_Unbounded_String (Object_Key (State));
            end;
         end loop;
         return False;
      end Proof_In_Only;

      function Shown (Key : String) return String
      is (if Key = Result_Key then "the result"
          elsif Libadalang.Analysis.Is_Null (Name_Of (Key)) then Key
          else Node_Text (Name_Of (Key)));
   begin
      if not Listed.Resolved then
         Report
           (Not_Analyzed, "", "a name in the Depends aspect was not resolved");
         return;
      end if;

      declare
         Global : constant Libadalang.Analysis.Expr :=
           (if Libadalang.Analysis.Is_Null
                 (Aspect_Expression (Subprogram, "Refined_Global"))
            then Contract (Subprogram, "Global")
            else Aspect_Expression (Subprogram, "Refined_Global"));
      begin
         if not Libadalang.Analysis.Is_Null (Global) then
            for Item of Parse_Global (Global).Items loop
               if Item.Mode = Proof_In then
                  Proof_Only.Include (Object_Key (Item.Site));
               end if;
            end loop;
         end if;
      end;

      declare
         Flows : constant Body_Flows := Analyze_Body (Subprogram);
      begin
         Enter (Subprogram);
         if not Flows.Known then
            Report (Not_Analyzed, "", To_String (Flows.Reason));
         else
            --  Each object outside the body that it writes is an output.
            for Position in Flows.Final.Values.Iterate loop
               declare
                  Root : constant String :=
                    Root_Of (Key_Set_Maps.Key (Position));
                  Name : constant Libadalang.Analysis.Defining_Name :=
                    Name_Of (Root);
               begin
                  if not Is_Local_Key (Root)
                    and then not (not Libadalang.Analysis.Is_Null (Name)
                                  and then Name.P_Is_Ghost_Code)
                    and then not Listed.Flows.Contains (Up (Root))
                  then
                     Report (Unlisted_Output, Shown (Root), "");
                  end if;
               end;
            end loop;

            --  Each output depends on what the aspect lists for it and on
            --  nothing else.
            for Position in Listed.Flows.Iterate loop
               declare
                  Output  : constant String := Key_Set_Maps.Key (Position);
                  Allowed : constant Key_Sets.Set :=
                    Key_Set_Maps.Element (Position);
                  Found   : Key_Sets.Set;
                  Sources : Key_Sets.Set;
               begin
                  if Output = Result_Key then
                     Found := Flows.Result;
                  elsif Output /= Null_Key and then Flows.Final.Alive then
                     declare
                        Parts : constant Key_Sets.Set :=
                          Visible_Constituents (Output);
                     begin
                        if Parts.Is_Empty then
                           Found := Value (Flows.Final, Output);
                        else
                           for Part of Parts loop
                              Found.Union (Value (Flows.Final, Part));
                           end loop;
                           if Flows.Final.Values.Contains (Output) then
                              Found.Union
                                (Flows.Final.Values.Element (Output));
                           end if;
                        end if;
                     end;
                  end if;

                  for Input of Found loop
                     declare
                        Source : constant String := Up (Input);
                     begin
                        Sources.Include (Source);
                        --  A part of the output left as it was is no flow
                        --  from a Proof_In object.
                        if Source /= Output and then Proof_In_Only (Input) then
                           Report (Proof_Flow, Shown (Output), Shown (Input));
                        elsif Source = ""
                          or else not Allowed.Contains (Source)
                        then
                           Report
                             (Missing_Flow, Shown (Output), Shown (Input));
                        end if;
                     end;
                  end loop;

                  --  What is listed and shown not to reach the output is
                  --  GNATprove's "incorrect dependency".
                  if Output /= Null_Key then
                     for Input of Allowed loop
                        if not Sources.Contains (Input) then
                           Report (Extra_Flow, Shown (Output), Shown (Input));
                        end if;
                     end loop;
                  end if;
               end;
            end loop;
         end if;
         Analyzed := Libadalang.Analysis.No_Ada_Node;
         Without_Input.Clear;
      end;
   exception
      when Exc : others =>
         Analyzed := Libadalang.Analysis.No_Ada_Node;
         Without_Input.Clear;
         Report
           (Not_Analyzed, "",
            "the dependencies were not worked out: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Check_Depends;

   procedure Verify_Depends
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Base_Subp_Body'Class;
      Depends    : Libadalang.Analysis.Expr)
   is
      Subject : constant String :=
        "Depends of " & Node_Text (Subprogram.P_Defining_Name);
      Failure : Unbounded_String;

      procedure Fail
        (Kind : Mismatch_Kind;
         Output, Input : String) is  --  adalang-analyzer: ignore Swappable_Parameters
      begin
         if Length (Failure) = 0 then
            Failure := To_Unbounded_String
              (case Kind is
                  when Not_Analyzed => Input,
                  when Unlisted_Output =>
                    Output & " is written and is not an output of the aspect",
                  when Missing_Flow =>
                    Output & " may depend on " & Input & ", which the " &
                    "aspect does not list for it",
                  when Extra_Flow =>
                    Output & " does not depend on " & Input & ", which the " &
                    "aspect lists for it",
                  when Proof_Flow =>
                    Output & " may depend on " & Input & ", which is " &
                    "listed as Proof_In");
         end if;
      end Fail;
   begin
      Check_Depends (Subprogram, Depends, Fail'Access);

      if Length (Failure) = 0 then
         Proof.Register_At
           (Unit             => Unit,
            Node             => Aspect_Anchor (Depends),
            Kind             => Proof.Flow_Dependencies_Check,
            Status           => Proof.Proved_Safe,
            Method           => Proof.Flow_Analysis,
            Operation        => Subject,
            Abstract_State   =>
              "each output may depend on what the aspect lists for it, " &
              "and on nothing else",
            Explanation      =>
              "the Depends aspect is the dependencies of the subprogram",
            Configuration_Id => Assurance_Profile_Name,
            Final            => True);
      else
         Proof.Register_At
           (Unit               => Unit,
            Node               => Aspect_Anchor (Depends),
            Kind               => Proof.Flow_Dependencies_Check,
            Status             => Proof.Unproved,
            Method             => Proof.Flow_Analysis,
            Operation          => Subject,
            Explanation        =>
              "the Depends aspect is not shown to be the dependencies of " &
              "the subprogram",
            Imprecision_Source => To_String (Failure),
            Configuration_Id   => Assurance_Profile_Name,
            Final              => True);
      end if;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("Depends aspect not checked for a subprogram: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Verify_Depends;

   procedure Clear_Flow_Dependencies is
   begin
      Object_Names.Clear;
      Body_Summaries.Clear;
      Constant_Keys.Clear;
   end Clear_Flow_Dependencies;

   procedure Verify_Unit (Unit : Libadalang.Analysis.Analysis_Unit) is
      procedure Visit (Node : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind in Libadalang.Common.Ada_Subp_Body
                 | Libadalang.Common.Ada_Expr_Function
           and then SPARK_Readiness.Effective_SPARK_Enabled
                      (Node.As_Basic_Decl)
         then
            declare
               Global  : constant Libadalang.Analysis.Expr :=
                 Contract (Node.As_Basic_Decl, "Global");
               Depends : constant Libadalang.Analysis.Expr :=
                 Contract (Node.As_Basic_Decl, "Depends");
            begin
               if not Libadalang.Analysis.Is_Null (Global) then
                  Verify_Global (Unit, Node.As_Base_Subp_Body, Global);
               end if;
               if not Libadalang.Analysis.Is_Null (Depends) then
                  Verify_Depends (Unit, Node.As_Base_Subp_Body, Depends);
               end if;
            end;
         end if;

         for Index in 1 .. Node.Children_Count loop
            Visit (Node.Child (Index));
         end loop;
      end Visit;
   begin
      Visit (Unit.Root);
   end Verify_Unit;

end Adalang_Analyzer.Flow_Contracts;
