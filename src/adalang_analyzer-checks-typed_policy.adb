--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Strings.Fixed;

with Langkit_Support.Slocs;
with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text; use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;   use Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;   use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;    use Adalang_Analyzer.Rules;

package body Adalang_Analyzer.Checks.Typed_Policy is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Base_Type_Decl;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Analysis.Defining_Name;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   subtype Node_Kind is Libadalang.Common.Ada_Node_Kind_Type;

   function Lower (Text : String) return String
     renames Ada.Characters.Handling.To_Lower;

   --  True when Item is one of the comma-separated entries of List,
   --  compared without regard to case.
   function Is_Listed (Item : String; List : String) return Boolean is
      Start : Positive := List'First;
   begin
      for I in List'First .. List'Last + 1 loop
         if I > List'Last or else List (I) = ',' then
            if Lower
                 (Ada.Strings.Fixed.Trim (List (Start .. I - 1), Ada.Strings.Both))
               = Lower (Item)
            then
               return True;
            end if;
            Start := I + 1;
         end if;
      end loop;
      return False;
   end Is_Listed;

   function Is_Set (Rule : Rule_Kind; Name : String) return Boolean
   is (Lower (Rule_Parameter (Rule, Name, "false")) = "true");

   --  The declaration an operator symbol or operator call resolves to is
   --  predefined when there is none, or when Libadalang says so.
   function Is_Predefined_Operator
     (Op : Libadalang.Analysis.Name'Class) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl := Op.P_Referenced_Decl;
   begin
      return Libadalang.Analysis.Is_Null (Decl)
        or else Decl.P_Is_Predefined_Operator;
   end Is_Predefined_Operator;

   --  The 1-based position of Node among its siblings.
   function Position
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
   begin
      for I in 1 .. Node.Parent.Children_Count loop
         if Node.Parent.Child (I) = Node.As_Ada_Node then
            return I;
         end if;
      end loop;
      return 0;
   end Position;

   function Has_Semantic_Ancestor
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Node.P_Semantic_Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Match (Current.Kind) then
            return True;
         end if;
         Current := Current.P_Semantic_Parent;
      end loop;
      return False;
   end Has_Semantic_Ancestor;

   function Has_Ancestor
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Match (Current.Kind) then
            return True;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Has_Ancestor;

   function Is_Executable_Body (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Base_Subp_Body
         | Libadalang.Common.Ada_Task_Body
         | Libadalang.Common.Ada_Entry_Body);

   function Is_Local_Scope (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Basic_Subp_Decl
         | Libadalang.Common.Ada_Subp_Body
         | Libadalang.Common.Ada_Task_Body
         | Libadalang.Common.Ada_Expr_Function
         | Libadalang.Common.Ada_Block_Stmt
         | Libadalang.Common.Ada_Entry_Body
         | Libadalang.Common.Ada_Protected_Body);

   function Is_Private_Part (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Private_Part);

   function Is_Qualifying_Context (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Qual_Expr
         | Libadalang.Common.Ada_Aspect_Clause);

   --  The formal parameter names of Spec, in declaration order, with
   --  whether each has a default.
   type Formal is record
      Name        : Libadalang.Analysis.Defining_Name;
      Has_Default : Boolean;
   end record;
   type Formal_List is array (Positive range <>) of Formal;

   function Formals
     (Spec : Libadalang.Analysis.Base_Subp_Spec'Class) return Formal_List
   is
      Specs : constant Libadalang.Analysis.Param_Spec_Array := Spec.P_Params;
      Total : Natural := 0;
   begin
      for S of Specs loop
         Total := Total + S.F_Ids.Children_Count;
      end loop;

      return Result : Formal_List (1 .. Total) do
         Total := 0;
         for S of Specs loop
            for I in 1 .. S.F_Ids.Children_Count loop
               Total := Total + 1;
               Result (Total) :=
                 (Name        => S.F_Ids.Child (I).As_Defining_Name,
                  Has_Default =>
                    not Libadalang.Analysis.Is_Null (S.F_Default_Expr));
            end loop;
         end loop;
      end return;
   end Formals;

   --  Positional_Parameter and Positional_Defaulted_Parameter, on a
   --  positional association of a subprogram or entry call.
   procedure Analyze_Call_Association
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class;
      Call : Libadalang.Analysis.Call_Expr)
   is
      Callee : constant Libadalang.Analysis.Name := Call.F_Name;
      Holder : Libadalang.Analysis.Base_Formal_Param_Holder;
   begin
      if not Call.P_Is_Call then
         return;
      end if;

      Holder := Call.P_Called_Subp_Spec;
      if Libadalang.Analysis.Is_Null (Holder) then
         return;
      end if;

      if Rule_States (Positional_Defaulted_Parameter) = Enabled then
         declare
            Params : Libadalang.Analysis.Params;
            Left   : Natural := Position (Node);
         begin
            if Holder.Kind = Libadalang.Common.Ada_Subp_Spec then
               Params := Holder.As_Subp_Spec.F_Subp_Params;
            elsif Holder.Kind = Libadalang.Common.Ada_Entry_Spec then
               Params := Holder.As_Entry_Spec.F_Entry_Params;
            end if;

            if not Libadalang.Analysis.Is_Null (Params) then
               for I in 1 .. Params.F_Params.Children_Count loop
                  declare
                     Spec : constant Libadalang.Analysis.Param_Spec :=
                       Params.F_Params.Child (I).As_Param_Spec;
                  begin
                     if Left <= Spec.F_Ids.Children_Count then
                        if not Libadalang.Analysis.Is_Null
                                 (Spec.F_Default_Expr)
                        then
                           Report_Rule_Violation
                             (Unit, Node, Positional_Defaulted_Parameter,
                              "positional actual for a defaulted parameter");
                        end if;
                        exit;
                     end if;
                     Left := Left - Spec.F_Ids.Children_Count;
                  end;
               end loop;
            end if;
         end;
      end if;

      if Rule_States (Positional_Parameter) /= Enabled
        or else Holder.Kind /= Libadalang.Common.Ada_Subp_Spec
        or else Callee.Kind = Libadalang.Common.Ada_Attribute_Ref
        or else Callee.P_Is_Operator_Name
      then
         return;
      end if;

      declare
         All_Calls : constant Boolean := Is_Set (Positional_Parameter, "all");
         Known     : constant Formal_List := Formals (Holder.As_Subp_Spec);
         Minimum   : constant Natural :=
           (if Callee.P_Is_Dot_Call then 2 else 1);
         This      : Libadalang.Analysis.Defining_Name :=
           Libadalang.Analysis.No_Defining_Name;
         Needed    : Boolean := Call.F_Suffix.Children_Count > 1;
      begin
         if not All_Calls then
            if Known'Length <= Minimum then
               return;
            end if;

            for Pair of Call.P_Call_Params loop
               if Libadalang.Analysis.Actual (Pair).As_Ada_Node =
                    Node.As_Param_Assoc.F_R_Expr.As_Ada_Node
               then
                  This := Libadalang.Analysis.Param (Pair).As_Defining_Name;
               end if;
            end loop;

            --  One actual may stay positional only when it is the single
            --  parameter without a default.
            for F of Known loop
               if (if F.Name = This then F.Has_Default else not F.Has_Default)
               then
                  Needed := True;
               end if;
            end loop;

            if not Needed then
               return;
            end if;
         end if;

         Report_Rule_Violation
           (Unit, Node, Positional_Parameter,
            "positional parameter association");
      end;
   end Analyze_Call_Association;

   --  The number of generic formal parameters Decl declares.
   function Generic_Formal_Count
     (Decl : Libadalang.Analysis.Generic_Decl) return Natural
   is
      Items : constant Libadalang.Analysis.Ada_Node_List :=
        Decl.F_Formal_Part.F_Decls;
      Total : Natural := 0;
   begin
      for I in 1 .. Items.Children_Count loop
         if Items.Child (I).Kind in Libadalang.Common.Ada_Generic_Formal then
            declare
               Inner : constant Libadalang.Analysis.Basic_Decl :=
                 Items.Child (I).As_Generic_Formal.F_Decl;
            begin
               if Inner.Kind = Libadalang.Common.Ada_Object_Decl then
                  Total := Total + Inner.As_Object_Decl.F_Ids.Children_Count;
               elsif Inner.Kind = Libadalang.Common.Ada_Number_Decl then
                  Total := Total + Inner.As_Number_Decl.F_Ids.Children_Count;
               else
                  Total := Total + 1;
               end if;
            end;
         end if;
      end loop;
      return Total;
   end Generic_Formal_Count;

   procedure Analyze_Association
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Assoc : constant Libadalang.Analysis.Param_Assoc := Node.As_Param_Assoc;
      List  : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Owner : Libadalang.Analysis.Ada_Node;
   begin
      if not Libadalang.Analysis.Is_Null (Assoc.F_Designator)
        or else Libadalang.Analysis.Is_Null (List)
        or else List.Kind /= Libadalang.Common.Ada_Assoc_List
        or else Libadalang.Analysis.Is_Null (List.Parent)
      then
         return;
      end if;
      Owner := List.Parent;

      if Owner.Kind = Libadalang.Common.Ada_Call_Expr then
         Analyze_Call_Association (Unit, Node, Owner.As_Call_Expr);
      elsif Owner.Kind in Libadalang.Common.Ada_Generic_Instantiation
        and then Rule_States (Positional_Generic_Parameter) = Enabled
        and then Assoc.F_R_Expr.Kind /= Libadalang.Common.Ada_Box_Expr
        and then (List.Children_Count > 1
                  or else Generic_Formal_Count
                            (Owner.As_Generic_Instantiation
                               .P_Designated_Generic_Decl) > 1)
      then
         Report_Rule_Violation
           (Unit, Node, Positional_Generic_Parameter,
            "positional generic association");
      end if;
   end Analyze_Association;

   --  Positional_Component and Non_Qualified_Aggregate.
   procedure Analyze_Aggregate
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Aggregate : constant Libadalang.Analysis.Base_Aggregate :=
        Node.As_Base_Aggregate;

      function Is_Named_Type_Aggregate
        (Item : Libadalang.Analysis.Ada_Node) return Boolean
      is
         Item_Type : Libadalang.Analysis.Base_Type_Decl;
      begin
         if Item.Kind not in Libadalang.Common.Ada_Aggregate
              | Libadalang.Common.Ada_Bracket_Aggregate
         then
            return False;
         end if;
         Item_Type := Item.As_Expr.P_Expression_Type;
         return Libadalang.Analysis.Is_Null (Item_Type)
           or else Item_Type.Kind /= Libadalang.Common.Ada_Anonymous_Type_Decl;
      exception
         when others =>
            return True;
      end Is_Named_Type_Aggregate;
   begin
      if Rule_States (Positional_Component) = Enabled then
         declare
            Positional : Boolean := False;
            Assocs     : constant Libadalang.Analysis.Assoc_List :=
              Aggregate.F_Assocs;
         begin
            for I in 1 .. Assocs.Children_Count loop
               if Assocs.Child (I).Kind = Libadalang.Common.Ada_Aggregate_Assoc
                 and then Assocs.Child (I).As_Aggregate_Assoc.F_Designators
                            .Children_Count = 0
               then
                  Positional := True;
               end if;
            end loop;

            if Positional then
               declare
                  Aggregate_Type : constant Libadalang.Analysis.Base_Type_Decl
                    := Aggregate.P_Expression_Type;
               begin
                  if not Libadalang.Analysis.Is_Null (Aggregate_Type)
                    and then (Aggregate_Type.P_Is_Array_Type
                              or else Aggregate_Type.P_Is_Record_Type)
                  then
                     Report_Rule_Violation
                       (Unit, Node, Positional_Component,
                        "aggregate with a positional component association");
                  end if;
               end;
            end if;
         end;
      end if;

      if Rule_States (Non_Qualified_Aggregate) = Enabled
        and then Is_Named_Type_Aggregate (Node.As_Ada_Node)
        and then not Aggregate.P_Is_Subaggregate
        and then not Has_Ancestor (Node, Is_Qualifying_Context'Access)
      then
         declare
            Current : Libadalang.Analysis.Ada_Node := Node.Parent;
         begin
            while not Libadalang.Analysis.Is_Null (Current) loop
               if Is_Named_Type_Aggregate (Current) then
                  return;
               end if;
               Current := Current.Parent;
            end loop;
         end;

         Report_Rule_Violation
           (Unit, Node, Non_Qualified_Aggregate,
            "aggregate is not the operand of a qualified expression");
      end if;
   end Analyze_Aggregate;

   procedure Analyze_Nested_Subprogram
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind    : constant Node_Kind := Node.Kind;
      Is_Body : constant Boolean :=
        Kind in Libadalang.Common.Ada_Subp_Body
          | Libadalang.Common.Ada_Expr_Function
          | Libadalang.Common.Ada_Subp_Body_Stub;
      Owner   : Libadalang.Analysis.Ada_Node;
   begin
      if Is_Body then
         declare
            Previous : constant Libadalang.Analysis.Basic_Decl :=
              Node.As_Body_Node.P_Previous_Part;
         begin
            if not Libadalang.Analysis.Is_Null (Previous)
              and then Previous.Kind /= Libadalang.Common.Ada_Subp_Body_Stub
            then
               return;
            end if;
         end;
      end if;

      Owner := Node.P_Semantic_Parent;
      if not Libadalang.Analysis.Is_Null (Owner)
        and then Owner.Kind in Libadalang.Common.Ada_Protected_Type_Decl
                   | Libadalang.Common.Ada_Single_Protected_Decl
      then
         return;
      end if;

      if Kind in Libadalang.Common.Ada_Classic_Subp_Decl then
         declare
            Completion : constant Libadalang.Analysis.Base_Subp_Body :=
              Node.As_Classic_Subp_Decl.P_Body_Part;
         begin
            if not Libadalang.Analysis.Is_Null (Completion)
              and then Completion.Kind = Libadalang.Common.Ada_Null_Subp_Decl
            then
               return;
            end if;
         end;
      end if;

      if Has_Semantic_Ancestor (Node, Is_Executable_Body'Access) then
         Report_Rule_Violation
           (Unit, Node, Nested_Subprogram,
            "subprogram declared in an executable body");
      end if;
   end Analyze_Nested_Subprogram;

   function Is_Boolean
     (Operand : Libadalang.Analysis.Expr'Class) return Boolean
   is
      Operand_Type : constant Libadalang.Analysis.Base_Type_Decl :=
        Operand.P_Expression_Type;
   begin
      return not Libadalang.Analysis.Is_Null (Operand_Type)
        and then Operand_Type.P_Base_Subtype = Operand.P_Bool_Type;
   end Is_Boolean;

   --  Boolean_Relational_Operator and Fixed_Equality.
   procedure Analyze_Relation
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Relation : constant Libadalang.Analysis.Relation_Op :=
        Node.As_Relation_Op;
   begin
      if not Is_Predefined_Operator (Relation.F_Op) then
         return;
      end if;

      if Rule_States (Boolean_Relational_Operator) = Enabled
        and then Is_Boolean (Relation)
        and then Is_Boolean (Relation.F_Left)
      then
         Report_Rule_Violation
           (Unit, Node, Boolean_Relational_Operator,
            "relational operator applied to Boolean values");
      end if;

      if Rule_States (Fixed_Equality) = Enabled
        and then Relation.F_Op.Kind in Libadalang.Common.Ada_Op_Eq
                   | Libadalang.Common.Ada_Op_Neq
      then
         declare
            Left_Type : constant Libadalang.Analysis.Base_Type_Decl :=
              Relation.F_Left.P_Expression_Type;
         begin
            if not Libadalang.Analysis.Is_Null (Left_Type)
              and then Left_Type.P_Is_Fixed_Point
            then
               Report_Rule_Violation
                 (Unit, Node, Fixed_Equality,
                  "equality operation on fixed-point values");
            end if;
         end;
      end if;
   end Analyze_Relation;

   procedure Analyze_Array_Return
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
      Spec : Libadalang.Analysis.Subp_Spec;
   begin
      if Kind in Libadalang.Common.Ada_Base_Subp_Body then
         Spec := Node.As_Base_Subp_Body.F_Subp_Spec;
      elsif Kind = Libadalang.Common.Ada_Subp_Body_Stub then
         Spec := Node.As_Subp_Body_Stub.F_Subp_Spec;
      elsif Kind = Libadalang.Common.Ada_Generic_Subp_Internal then
         Spec := Node.As_Generic_Subp_Internal.F_Subp_Spec;
      else
         Spec := Node.As_Classic_Subp_Decl.F_Subp_Spec;
      end if;

      if Libadalang.Analysis.Is_Null (Spec.F_Subp_Returns) then
         return;
      end if;

      if Kind in Libadalang.Common.Ada_Base_Subp_Body
           | Libadalang.Common.Ada_Subp_Body_Stub
        and then not Libadalang.Analysis.Is_Null
                       (Node.As_Body_Node.P_Previous_Part)
      then
         return;
      end if;

      declare
         Result : constant Libadalang.Analysis.Type_Expr :=
           Spec.F_Subp_Returns;
         Result_Type : Libadalang.Analysis.Base_Type_Decl;
      begin
         if Result.P_Is_Definite_Subtype then
            return;
         end if;

         Result_Type := Result.P_Designated_Type_Decl;
         if Libadalang.Analysis.Is_Null (Result_Type) then
            return;
         end if;
         Result_Type := Result_Type.P_Root_Type;

         if not Libadalang.Analysis.Is_Null (Result_Type)
           and then Result_Type.Kind in Libadalang.Common.Ada_Type_Decl
           and then Result_Type.P_Is_Array_Type
           and then Result_Type.As_Type_Decl.F_Type_Def.Kind =
                      Libadalang.Common.Ada_Array_Type_Def
           and then Result_Type.As_Type_Decl.F_Type_Def.As_Array_Type_Def
                      .F_Indices.Kind =
                    Libadalang.Common.Ada_Unconstrained_Array_Indices
         then
            Report_Rule_Violation
              (Unit, Node, Unconstrained_Array_Return,
               "function returns an unconstrained array");
         end if;
      end;
   end Analyze_Array_Return;

   --  True when Type_Decl's root type is declared in a predefined library
   --  hierarchy: Standard, System, Ada or Interfaces.
   function Is_Predefined_Type
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is
      Root    : Libadalang.Analysis.Base_Type_Decl := Type_Decl.P_Root_Type;
      Current : Libadalang.Analysis.Ada_Node;
      Outer   : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
   begin
      for Step in 1 .. 8 loop
         exit when Libadalang.Analysis.Is_Null (Root)
           or else not Root.P_Is_Private;
         declare
            Full : constant Libadalang.Analysis.Base_Type_Decl :=
              Root.P_Full_View;
         begin
            exit when Libadalang.Analysis.Is_Null (Full) or else Full = Root;
            Root := Full.P_Root_Type;
         end;
      end loop;

      if Libadalang.Analysis.Is_Null (Root) then
         return False;
      end if;

      Current := Root.Parent;
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Base_Package_Decl then
            Outer := Current;
         end if;
         Current := Current.Parent;
      end loop;

      if Libadalang.Analysis.Is_Null (Outer) then
         return False;
      end if;

      declare
         Unit_Name : constant String :=
           Lower (Node_Text (Outer.As_Base_Package_Decl.F_Package_Name));
         Dot       : constant Natural :=
           Ada.Strings.Fixed.Index (Unit_Name, ".");
         Top       : constant String :=
           (if Dot = 0 then Unit_Name
            else Unit_Name (Unit_Name'First .. Dot - 1));
      begin
         return Top = "standard" or else Top = "system"
           or else Top = "ada" or else Top = "interfaces";
      end;
   end Is_Predefined_Type;

   procedure Analyze_Derivation
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Def : constant Libadalang.Analysis.Derived_Type_Def :=
        Node.As_Derived_Type_Def;
      Parent_Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if not Libadalang.Analysis.Is_Null (Def.F_Record_Extension)
        or else Def.F_Has_With_Private.Kind /=
                  Libadalang.Common.Ada_With_Private_Absent
      then
         return;
      end if;

      Parent_Decl := Def.F_Subtype_Indication.F_Name.P_Referenced_Decl;
      if not Libadalang.Analysis.Is_Null (Parent_Decl)
        and then Parent_Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
        and then Is_Predefined_Type (Parent_Decl.As_Base_Type_Decl)
      then
         Report_Rule_Violation
           (Unit, Node, Deriving_From_Predefined_Type,
            "type derived from a predefined type");
      end if;
   end Analyze_Derivation;

   procedure Analyze_Visible_Components
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl    : constant Libadalang.Analysis.Type_Decl := Node.As_Type_Decl;
      Def     : constant Libadalang.Analysis.Type_Def := Decl.F_Type_Def;
      Part    : Libadalang.Analysis.Ada_Node;
      Current : Libadalang.Analysis.Ada_Node;
      Library : Boolean := False;
   begin
      if Libadalang.Analysis.Is_Null (Def)
        or else not (Def.Kind = Libadalang.Common.Ada_Record_Type_Def
                     or else (Def.Kind = Libadalang.Common.Ada_Derived_Type_Def
                              and then not Def.As_Derived_Type_Def
                                             .F_Has_With_Private.P_As_Bool))
        or else Libadalang.Analysis.Is_Null (Node.Parent)
      then
         return;
      end if;

      Part := Node.Parent.Parent;
      if Libadalang.Analysis.Is_Null (Part)
        or else Part.Kind /= Libadalang.Common.Ada_Public_Part
        or else Libadalang.Analysis.Is_Null (Part.Parent)
        or else Part.Parent.Kind not in
                  Libadalang.Common.Ada_Base_Package_Decl
        or else Has_Ancestor (Node, Is_Private_Part'Access)
      then
         return;
      end if;

      --  The package must belong to a library unit that is a package or a
      --  generic and is not a private unit.
      Current := Part.Parent.Parent;
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Library_Item then
            Library :=
              Current.As_Library_Item.F_Has_Private.Kind =
                Libadalang.Common.Ada_Private_Absent
              and then Current.As_Library_Item.F_Item.Kind in
                         Libadalang.Common.Ada_Package_Decl
                         | Libadalang.Common.Ada_Generic_Decl;
         end if;
         Current := Current.Parent;
      end loop;

      if Library
        and then Decl.P_Is_Record_Type
        and then (not Is_Set (Visible_Component, "tagged_only")
                  or else Decl.P_Is_Tagged_Type)
      then
         Report_Rule_Violation
           (Unit, Node, Visible_Component,
            "type has publicly accessible components");
      end if;
   end Analyze_Visible_Components;

   --  True when Node is declared in a package rather than in a
   --  subprogram, task, entry, block or protected unit.
   function Is_In_Package_Scope
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Base_Package_Decl
              | Libadalang.Common.Ada_Package_Body
         then
            return True;
         elsif Current.Kind in Libadalang.Common.Ada_Single_Task_Decl
                 | Libadalang.Common.Ada_Task_Type_Decl_Range
                 | Libadalang.Common.Ada_Task_Body
                 | Libadalang.Common.Ada_Block_Stmt
                 | Libadalang.Common.Ada_Base_Subp_Body
                 | Libadalang.Common.Ada_Entry_Body
                 | Libadalang.Common.Ada_Single_Protected_Decl
                 | Libadalang.Common.Ada_Protected_Type_Decl
         then
            return False;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_In_Package_Scope;

   procedure Analyze_Numeric_Index
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Operand : Libadalang.Analysis.Ada_Node := Node.As_Ada_Node;
      Call    : Libadalang.Analysis.Ada_Node;
   begin
      if not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind = Libadalang.Common.Ada_Un_Op
        and then Node.Parent.As_Un_Op.F_Op.Kind =
                   Libadalang.Common.Ada_Op_Minus
        and then Is_Predefined_Operator (Node.Parent.As_Un_Op.F_Op)
      then
         Operand := Node.Parent;
      end if;

      Call := Operand;
      for Level in 1 .. 3 loop
         Call := Call.Parent;
         if Libadalang.Analysis.Is_Null (Call) then
            return;
         end if;
      end loop;

      if Call.Kind = Libadalang.Common.Ada_Call_Expr then
         declare
            Prefix_Type : constant Libadalang.Analysis.Base_Type_Decl :=
              Call.As_Call_Expr.F_Name.P_Expression_Type;
         begin
            if not Libadalang.Analysis.Is_Null (Prefix_Type)
              and then Prefix_Type.P_Is_Array_Type
            then
               Report_Rule_Violation
                 (Unit, Node, Numeric_Indexing,
                  "integer literal used as an index value");
            end if;
         end;
      end if;
   end Analyze_Numeric_Index;

   procedure Analyze_Instantiation
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if (not Libadalang.Analysis.Is_Null (Node.Parent)
          and then Node.Parent.Kind =
                     Libadalang.Common.Ada_Generic_Formal_Obj_Decl)
        or else Has_Semantic_Ancestor (Node, Is_Local_Scope'Access)
      then
         Report_Rule_Violation
           (Unit, Node, Local_Instantiation, "local generic instantiation");
      end if;
   end Analyze_Instantiation;

   procedure Analyze_Inlining
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Is_Body : constant Boolean :=
        Node.Kind in Libadalang.Common.Ada_Subp_Body
          | Libadalang.Common.Ada_Expr_Function
          | Libadalang.Common.Ada_Subp_Body_Stub;
   begin
      if Node.As_Basic_Decl.P_Has_Aspect
           (Langkit_Support.Text.To_Unbounded_Text ("Inline"))
        and then (not Is_Body
                  or else Libadalang.Analysis.Is_Null
                            (Node.As_Body_Node.P_Previous_Part))
      then
         Report_Rule_Violation
           (Unit, Node, Explicit_Inlining, "subprogram marked Inline");
      end if;
   end Analyze_Inlining;

   --  Pos_On_Enumeration_Type and Forbidden_Attribute.
   procedure Analyze_Attribute
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Ref  : constant Libadalang.Analysis.Attribute_Ref :=
        Node.As_Attribute_Ref;
      Name : constant String := Canonical_Text (Ref.F_Attribute);
   begin
      if Rule_States (Forbidden_Attribute) = Enabled
        and then (Is_Set (Forbidden_Attribute, "all")
                  or else Is_Listed
                            (Name,
                             Rule_Parameter
                               (Forbidden_Attribute, "forbidden", "")))
        and then not Is_Listed
                       (Name,
                        Rule_Parameter (Forbidden_Attribute, "allowed", ""))
      then
         Report_Rule_Violation
           (Unit, Node, Forbidden_Attribute,
            "attribute " & Node_Text (Ref.F_Attribute) & " used");
      end if;

      if Rule_States (Pos_On_Enumeration_Type) = Enabled
        and then Name = "pos"
      then
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Ref.F_Prefix.P_Referenced_Decl;
         begin
            if not Libadalang.Analysis.Is_Null (Decl)
              and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
              and then Decl.As_Base_Type_Decl.P_Is_Enum_Type
            then
               Report_Rule_Violation
                 (Unit, Node, Pos_On_Enumeration_Type,
                  "Pos attribute applied to an enumeration type");
            end if;
         end;
      end if;
   end Analyze_Attribute;

   procedure Analyze_Fixed_Point_Small
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Def : constant Libadalang.Analysis.Type_Def :=
        Node.As_Type_Decl.F_Type_Def;
   begin
      if not Libadalang.Analysis.Is_Null (Def)
        and then Def.Kind = Libadalang.Common.Ada_Ordinary_Fixed_Point_Def
        and then not Node.As_Basic_Decl.P_Has_Aspect
                       (Langkit_Support.Text.To_Unbounded_Text ("Small"))
      then
         Report_Rule_Violation
           (Unit, Node, Implicit_Small,
            "fixed point type declared without a Small clause");
      end if;
   end Analyze_Fixed_Point_Small;

   procedure Analyze_Formal_Package
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Params : constant Libadalang.Analysis.Assoc_List :=
        Node.As_Generic_Package_Instantiation.F_Params;
      Boxes  : Natural := 0;
   begin
      for I in 1 .. Params.Children_Count loop
         if Params.Child (I).As_Param_Assoc.F_R_Expr.Kind =
              Libadalang.Common.Ada_Box_Expr
         then
            Boxes := Boxes + 1;
         end if;
      end loop;

      if Boxes > 1
        or else (Boxes = 1
                 and then (Params.Children_Count > 1
                           or else not Libadalang.Analysis.Is_Null
                                         (Params.Child (1).As_Param_Assoc
                                            .F_Designator)))
      then
         Report_Rule_Violation
           (Unit, Node, Ada05_Formal_Package,
            "formal package uses the Ada 2005 partial parameterization");
      end if;
   end Analyze_Formal_Package;

   function Exception_Name
     (Choice : Libadalang.Analysis.Ada_Node) return String
   is
   begin
      if Choice.Kind not in Libadalang.Common.Ada_Name then
         return "";
      end if;

      declare
         Definition : constant Libadalang.Analysis.Defining_Name :=
           Choice.As_Name.P_Referenced_Defining_Name;
      begin
         return (if Libadalang.Analysis.Is_Null (Definition) then ""
                 else Lower
                        (Langkit_Support.Text.To_UTF8
                           (Definition.P_Canonical_Fully_Qualified_Name)));
      end;
   exception
      when others =>
         return "";
   end Exception_Name;

   --  Reports Constraint_Error or Numeric_Error handled without the other
   --  in the same handler: the two denote the same exception since Ada 95.
   procedure Analyze_Handler_Choice
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Choices : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Name    : constant String := Exception_Name (Node.As_Ada_Node);
      Other   : constant String :=
        (if Name = "standard.constraint_error" then "standard.numeric_error"
         elsif Name = "standard.numeric_error"
         then "standard.constraint_error"
         else "");
   begin
      if Other = "" then
         return;
      end if;

      for I in 1 .. Choices.Children_Count loop
         if Exception_Name (Choices.Child (I)) = Other then
            return;
         end if;
      end loop;

      Report_Rule_Violation
        (Unit, Node, Separate_Numeric_Error_Handler,
         "Constraint_Error and Numeric_Error are not handled together");
   end Analyze_Handler_Choice;

   procedure Analyze_Tagged_Types
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Decls : constant Libadalang.Analysis.Ada_Node_List :=
        Node.As_Base_Package_Decl.F_Public_Part.F_Decls;
      Total : Natural := 0;
   begin
      for I in 1 .. Decls.Children_Count loop
         if Decls.Child (I).Kind in Libadalang.Common.Ada_Base_Type_Decl
           and then Decls.Child (I).As_Base_Type_Decl.P_Is_Tagged_Type
         then
            Total := Total + 1;
         end if;
      end loop;

      if Total > 1 then
         Report_Rule_Violation
           (Unit, Node, One_Tagged_Type_Per_Package,
            "more than one tagged type declared in the package "
            & "specification");
      end if;
   end Analyze_Tagged_Types;

   function Is_Universal_Integer
     (Bound : Libadalang.Analysis.Expr'Class) return Boolean
   is
   begin
      if Bound.Kind = Libadalang.Common.Ada_Int_Literal then
         return True;
      elsif Bound.Kind not in Libadalang.Common.Ada_Name then
         return False;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Bound.As_Name.P_Referenced_Decl;
      begin
         return not Libadalang.Analysis.Is_Null (Decl)
           and then Decl.Kind = Libadalang.Common.Ada_Number_Decl;
      end;
   exception
      when others =>
         return False;
   end Is_Universal_Integer;

   function Is_Universal_Range
     (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (Item.Kind = Libadalang.Common.Ada_Bin_Op
       and then Item.As_Bin_Op.F_Op.Kind = Libadalang.Common.Ada_Op_Double_Dot
       and then Is_Universal_Integer (Item.As_Bin_Op.F_Left)
       and then Is_Universal_Integer (Item.As_Bin_Op.F_Right));

   --  Explicit_Full_Discrete_Range and the loop form of Universal_Range.
   procedure Analyze_Range
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Operation : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
      Low       : constant Libadalang.Analysis.Expr := Operation.F_Left;
      High      : constant Libadalang.Analysis.Expr := Operation.F_Right;
   begin
      if Operation.F_Op.Kind /= Libadalang.Common.Ada_Op_Double_Dot
        or else Libadalang.Analysis.Is_Null (Node.Parent)
      then
         return;
      end if;

      if Rule_States (Universal_Range) = Enabled
        and then Node.Parent.Kind = Libadalang.Common.Ada_For_Loop_Spec
        and then Is_Universal_Range (Node)
      then
         Report_Rule_Violation
           (Unit, Node, Universal_Range,
            "range with universal integer bounds");
      end if;

      if Rule_States (Explicit_Full_Discrete_Range) = Enabled
        and then Node.Parent.Kind /= Libadalang.Common.Ada_Range_Spec
        and then Low.Kind = Libadalang.Common.Ada_Attribute_Ref
        and then High.Kind = Libadalang.Common.Ada_Attribute_Ref
        and then Canonical_Text (Low.As_Attribute_Ref.F_Attribute) = "first"
        and then Canonical_Text (High.As_Attribute_Ref.F_Attribute) = "last"
        and then not Low.As_Attribute_Ref.F_Prefix.P_Is_Call
        and then Low.As_Attribute_Ref.F_Prefix.P_Referenced_Decl =
                   High.As_Attribute_Ref.F_Prefix.P_Referenced_Decl
      then
         Report_Rule_Violation
           (Unit, Node, Explicit_Full_Discrete_Range,
            "range can be written as a subtype mark or a Range attribute");
      end if;
   end Analyze_Range;

   procedure Analyze_Index_Constraint
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Constraint : constant Libadalang.Analysis.Composite_Constraint :=
        Node.As_Composite_Constraint;
   begin
      if Constraint.P_Is_Index_Constraint
        and then Constraint.F_Constraints.Children_Count > 0
        and then Is_Universal_Range
                   (Constraint.F_Constraints.Child (1)
                      .As_Composite_Constraint_Assoc.F_Constraint_Expr)
      then
         Report_Rule_Violation
           (Unit, Node, Universal_Range,
            "range with universal integer bounds");
      end if;
   end Analyze_Index_Constraint;

   --  True when the handlers of Stmts include an others choice.
   function Has_Others_Handler
     (Stmts : Libadalang.Analysis.Handled_Stmts) return Boolean
   is
      Handlers : constant Libadalang.Analysis.Ada_Node_List :=
        Stmts.F_Exceptions;
   begin
      for I in 1 .. Handlers.Children_Count loop
         if Handlers.Child (I).Kind = Libadalang.Common.Ada_Exception_Handler
         then
            declare
               Choices : constant Libadalang.Analysis.Alternatives_List :=
                 Handlers.Child (I).As_Exception_Handler.F_Handled_Exceptions;
            begin
               for J in 1 .. Choices.Children_Count loop
                  if Choices.Child (J).Kind =
                       Libadalang.Common.Ada_Others_Designator
                  then
                     return True;
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return False;
   end Has_Others_Handler;

   --  Missing_Others_Handler has three independent scopes, each switched
   --  on by a parameter: every handler part, subprogram bodies, task
   --  bodies. A body with no handler at all is not reported.
   procedure Analyze_Handler_Completeness
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind  : constant Node_Kind := Node.Kind;
      Stmts : Libadalang.Analysis.Handled_Stmts;
   begin
      if Kind = Libadalang.Common.Ada_Handled_Stmts then
         if not Is_Set (Missing_Others_Handler, "all_handlers") then
            return;
         end if;
         Stmts := Node.As_Handled_Stmts;
      elsif Kind = Libadalang.Common.Ada_Subp_Body then
         if not Is_Set (Missing_Others_Handler, "subprogram") then
            return;
         end if;
         Stmts := Node.As_Subp_Body.F_Stmts;
      else
         if not Is_Set (Missing_Others_Handler, "task") then
            return;
         end if;
         Stmts := Node.As_Task_Body.F_Stmts;
      end if;

      if Libadalang.Analysis.Is_Null (Stmts)
        or else Stmts.F_Exceptions.Children_Count = 0
        or else Has_Others_Handler (Stmts)
      then
         return;
      end if;

      if Kind = Libadalang.Common.Ada_Handled_Stmts then
         --  Reported at the exception keyword.
         declare
            Where : constant Langkit_Support.Slocs.Source_Location_Range :=
              Libadalang.Common.Sloc_Range
                (Libadalang.Common.Data
                   (Libadalang.Common.Previous
                      (Stmts.F_Exceptions.Token_Start,
                       Exclude_Trivia => True)));
         begin
            Report_Line_Violation
              (Filename    => Safe_Filename (Unit),
               Line_Number => Natural (Where.Start_Line),
               Column      => Natural (Where.Start_Column),
               Caret_Width => 9,
               Rule        => Missing_Others_Handler,
               Message     => "exception handlers have no others choice");
         end;
      else
         Report_Rule_Violation
           (Unit, Node, Missing_Others_Handler,
            (if Kind = Libadalang.Common.Ada_Task_Body
             then "task body has no others exception handler"
             else "subprogram body has no others exception handler"));
      end if;
   end Analyze_Handler_Completeness;

   procedure Analyze_Dependence
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Units : constant String :=
        Rule_Parameter (Forbidden_Dependence, "unit_names", "");
   begin
      if Units /= ""
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then not Libadalang.Analysis.Is_Null (Node.Parent.Parent)
        and then Node.Parent.Parent.Kind = Libadalang.Common.Ada_With_Clause
        and then Is_Listed (Node_Text (Node), Units)
      then
         Report_Rule_Violation
           (Unit, Node, Forbidden_Dependence,
            "dependence on " & Node_Text (Node) & " is forbidden");
      end if;
   end Analyze_Dependence;

   --  Runs one check procedure with its own exception boundary.
   procedure Guarded
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      Rule  : Rule_Kind;
      Check : not null access procedure
        (Unit : Libadalang.Analysis.Analysis_Unit;
         Node : Libadalang.Analysis.Ada_Node'Class))
   is
   begin
      if Rule_States (Rule) = Enabled then
         Check (Unit, Node);
      end if;
   exception
      when Exc : others =>
         Note_Skipped_Check (Node, Exc);
   end Guarded;

   --  As Guarded, for a procedure that serves several checks and tests
   --  their states itself.
   procedure Guarded_Any
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Enabled : Boolean;
      Check   : not null access procedure
        (Unit : Libadalang.Analysis.Analysis_Unit;
         Node : Libadalang.Analysis.Ada_Node'Class))
   is
   begin
      if Enabled then
         Check (Unit, Node);
      end if;
   exception
      when Exc : others =>
         Note_Skipped_Check (Node, Exc);
   end Guarded_Any;

   function On (Rule : Rule_Kind) return Boolean
   is (Rule_States (Rule) = Enabled);

   --  Checks keyed on an expression, name or association kind.
   procedure Analyze_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      if Kind = Libadalang.Common.Ada_Param_Assoc then
         Guarded_Any
           (Unit, Node,
            On (Positional_Parameter)
            or else On (Positional_Defaulted_Parameter)
            or else On (Positional_Generic_Parameter),
            Analyze_Association'Access);
      elsif Kind in Libadalang.Common.Ada_Aggregate
              | Libadalang.Common.Ada_Bracket_Aggregate
      then
         Guarded_Any
           (Unit, Node,
            On (Positional_Component) or else On (Non_Qualified_Aggregate),
            Analyze_Aggregate'Access);
      elsif Kind = Libadalang.Common.Ada_Relation_Op then
         Guarded_Any
           (Unit, Node,
            On (Boolean_Relational_Operator) or else On (Fixed_Equality),
            Analyze_Relation'Access);
      elsif Kind = Libadalang.Common.Ada_Int_Literal then
         Guarded (Unit, Node, Numeric_Indexing, Analyze_Numeric_Index'Access);
      elsif Kind = Libadalang.Common.Ada_Attribute_Ref then
         Guarded_Any
           (Unit, Node,
            On (Pos_On_Enumeration_Type) or else On (Forbidden_Attribute),
            Analyze_Attribute'Access);
      elsif Kind = Libadalang.Common.Ada_Bin_Op then
         Guarded_Any
           (Unit, Node,
            On (Universal_Range) or else On (Explicit_Full_Discrete_Range),
            Analyze_Range'Access);
      elsif Kind = Libadalang.Common.Ada_Composite_Constraint then
         Guarded (Unit, Node, Universal_Range, Analyze_Index_Constraint'Access);
      elsif Kind = Libadalang.Common.Ada_Aspect_Assoc then
         if On (Forbidden_Aspect) then
            declare
               Name : constant String :=
                 Node_Text (Node.As_Aspect_Assoc.F_Id);
            begin
               if (Is_Set (Forbidden_Aspect, "all")
                   or else Is_Listed
                             (Name,
                              Rule_Parameter
                                (Forbidden_Aspect, "forbidden", "")))
                 and then not Is_Listed
                                (Name,
                                 Rule_Parameter
                                   (Forbidden_Aspect, "allowed", ""))
               then
                  Report_Rule_Violation
                    (Unit, Node, Forbidden_Aspect,
                     "aspect " & Name & " used");
               end if;
            end;
         end if;
      end if;

      if Kind in Libadalang.Common.Ada_Name then
         Guarded (Unit, Node, Forbidden_Dependence, Analyze_Dependence'Access);

         if Kind in Libadalang.Common.Ada_Base_Id
           and then not Libadalang.Analysis.Is_Null (Node.Parent)
           and then Node.Parent.Kind = Libadalang.Common.Ada_Alternatives_List
           and then not Libadalang.Analysis.Is_Null (Node.Parent.Parent)
           and then Node.Parent.Parent.Kind =
                      Libadalang.Common.Ada_Exception_Handler
         then
            Guarded
              (Unit, Node, Separate_Numeric_Error_Handler,
               Analyze_Handler_Choice'Access);
         end if;
      end if;
   end Analyze_Expression;

   --  Checks keyed on a declaration, body or definition kind.
   procedure Analyze_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Expr_Function
           | Libadalang.Common.Ada_Subp_Body_Stub
           | Libadalang.Common.Ada_Basic_Subp_Decl
           | Libadalang.Common.Ada_Generic_Subp_Instantiation
      then
         Guarded
           (Unit, Node, Nested_Subprogram, Analyze_Nested_Subprogram'Access);
         Guarded (Unit, Node, Explicit_Inlining, Analyze_Inlining'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Abstract_Subp_Decl
           | Libadalang.Common.Ada_Subp_Decl
           | Libadalang.Common.Ada_Generic_Subp_Internal
           | Libadalang.Common.Ada_Base_Subp_Body
           | Libadalang.Common.Ada_Subp_Body_Stub
      then
         Guarded
           (Unit, Node, Unconstrained_Array_Return,
            Analyze_Array_Return'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Generic_Instantiation then
         Guarded
           (Unit, Node, Local_Instantiation, Analyze_Instantiation'Access);

         if Kind = Libadalang.Common.Ada_Generic_Package_Instantiation
           and then not Libadalang.Analysis.Is_Null (Node.Parent)
           and then Node.Parent.Kind =
                      Libadalang.Common.Ada_Generic_Formal_Package
         then
            Guarded
              (Unit, Node, Ada05_Formal_Package,
               Analyze_Formal_Package'Access);
         end if;
      elsif Kind = Libadalang.Common.Ada_Derived_Type_Def then
         Guarded
           (Unit, Node, Deriving_From_Predefined_Type,
            Analyze_Derivation'Access);
      elsif Kind in Libadalang.Common.Ada_Type_Decl then
         Guarded
           (Unit, Node, Visible_Component, Analyze_Visible_Components'Access);
         if Kind /= Libadalang.Common.Ada_Formal_Type_Decl then
            Guarded
              (Unit, Node, Implicit_Small, Analyze_Fixed_Point_Small'Access);
         end if;
      elsif Kind in Libadalang.Common.Ada_Object_Decl_Range then
         if On (Object_Of_Anonymous_Type)
           and then Node.As_Object_Decl.F_Type_Expr.Kind =
                      Libadalang.Common.Ada_Anonymous_Type
           and then Is_In_Package_Scope (Node)
         then
            Report_Rule_Violation
              (Unit, Node, Object_Of_Anonymous_Type,
               "object of an anonymous type declared in a package");
         end if;
      elsif Kind in Libadalang.Common.Ada_Base_Package_Decl then
         Guarded
           (Unit, Node, One_Tagged_Type_Per_Package,
            Analyze_Tagged_Types'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Handled_Stmts
           | Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Task_Body
      then
         Guarded
           (Unit, Node, Missing_Others_Handler,
            Analyze_Handler_Completeness'Access);
      end if;
   end Analyze_Declaration;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      Analyze_Expression (Unit, Node);
      Analyze_Declaration (Unit, Node);
   end Analyze_Node;

end Adalang_Analyzer.Checks.Typed_Policy;
