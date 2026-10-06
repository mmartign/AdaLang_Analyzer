--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Exceptions;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Slocs;
with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;    use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.SPARK_Readiness;
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

   procedure Reset is
   begin
      Known.Clear;
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
                     return Decl.As_Object_Decl.F_Has_Constant.Kind =
                         Libadalang.Common.Ada_Constant_Present
                       and then Libadalang.Analysis.Is_Null
                                  (Decl.As_Object_Decl.F_Renaming_Clause)
                       and then not Libadalang.Analysis.Is_Null
                                      (Decl.As_Object_Decl.F_Default_Expr)
                       and then Is_Variable_Free
                                  (Decl.As_Object_Decl.F_Default_Expr,
                                   Depth + 1);
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
           Decl.As_Object_Decl;
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
             (Object.F_Default_Expr.P_Is_Static_Expr
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

      function Is_Pure_Unit return Boolean is
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
                  Give_Up
                    (Result,
                     Name & " is a generic formal subprogram with no " &
                     "Global aspect");
               elsif Is_Pure_Unit then
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
                         .P_Designated_Generic_Decl
                         .P_Fully_Qualified_Name));
            begin
               if Generic_Name not in "ada.unchecked_conversion"
                    | "ada.unchecked_deallocation"
                    | "unchecked_conversion"
                    | "unchecked_deallocation"
               then
                  Give_Up
                    (Result,
                     "the effects of the generic instance " & Name &
                     " are not followed");
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

   procedure Verify_Depends
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Base_Subp_Body'Class;
      Depends    : Libadalang.Analysis.Expr) is
   begin
      Proof.Register_At
        (Unit               => Unit,
         Node               => Aspect_Anchor (Depends),
         Kind               => Proof.Flow_Dependencies_Check,
         Status             => Proof.Unproved,
         Method             => Proof.No_Analysis,
         Operation          =>
           "Depends of " & Node_Text (Subprogram.P_Defining_Name),
         Explanation        =>
           "the Depends aspect is not shown to be the dependencies of " &
           "the subprogram",
         Imprecision_Source =>
           "information flow is not yet analyzed to the point of proof",
         Configuration_Id   => Assurance_Profile_Name,
         Final              => True);
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("Depends aspect not recorded for a subprogram: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Verify_Depends;

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
