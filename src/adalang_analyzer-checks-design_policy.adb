--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text; use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;   use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;    use Adalang_Analyzer.Rules;

package body Adalang_Analyzer.Checks.Design_Policy is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Base_Type_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   subtype Node is Libadalang.Analysis.Ada_Node;

   function Is_Null (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
     renames Libadalang.Analysis.Is_Null;

   function Same_Name
     (Left, Right : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (not Is_Null (Left) and then not Is_Null (Right)
       and then Canonical_Text (Left) = Canonical_Text (Right));

   function Is_Attribute
     (Item : Libadalang.Analysis.Ada_Node'Class; Name : String) return Boolean
   is (not Is_Null (Item)
       and then Item.Kind = Libadalang.Common.Ada_Attribute_Ref
       and then Canonical_Text (Item.As_Attribute_Ref.F_Attribute) = Name);

   --  True when Match holds for Item or for some node below it.
   function Any_Node
     (Item  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Item : Node) return Boolean)
      return Boolean
   is
   begin
      if Is_Null (Item) then
         return False;
      elsif Match (Item.As_Ada_Node) then
         return True;
      end if;

      for I in 1 .. Item.Children_Count loop
         if Any_Node (Item.Child (I), Match) then
            return True;
         end if;
      end loop;
      return False;
   end Any_Node;

   function Referenced
     (Name : Libadalang.Analysis.Ada_Node'Class) return Node
   is
   begin
      if Is_Null (Name) or else Name.Kind not in Libadalang.Common.Ada_Name
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;
      return Name.As_Name.P_Referenced_Decl.As_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Referenced;

   function Names_A_Type
     (Name : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Decl : constant Node := Referenced (Name);
   begin
      return not Is_Null (Decl)
        and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl;
   end Names_A_Type;

   --  The nearest type declaration around Item, or a null node.
   function Enclosing_Type
     (Item : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Current : Node := Item.Parent;
   begin
      while not Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Type_Decl then
            return Current;
         end if;
         Current := Current.Parent;
      end loop;
      return Libadalang.Analysis.No_Ada_Node;
   end Enclosing_Type;

   ------------------------------
   --  Discriminated records   --
   ------------------------------

   --  True when discriminant Id of a derived type is passed unchanged to
   --  the parent type's discriminant constraint.
   function Is_Passed_To_Parent
     (Id : Node; Def : Libadalang.Analysis.Type_Def) return Boolean
   is
      function Uses (Item : Node) return Boolean is
         Assoc : Libadalang.Analysis.Composite_Constraint_Assoc;
      begin
         if Item.Kind /= Libadalang.Common.Ada_Composite_Constraint_Assoc
         then
            return False;
         end if;

         Assoc := Item.As_Composite_Constraint_Assoc;
         if Assoc.F_Constraint_Expr.Kind not in Libadalang.Common.Ada_Base_Id
           or else not Same_Name (Assoc.F_Constraint_Expr, Id)
         then
            return False;
         elsif Assoc.F_Ids.Children_Count = 0 then
            return True;
         end if;

         for I in 1 .. Assoc.F_Ids.Children_Count loop
            if Assoc.F_Ids.Child (I).Kind in Libadalang.Common.Ada_Base_Id
              and then Same_Name (Assoc.F_Ids.Child (I), Id)
            then
               return True;
            end if;
         end loop;
         return False;
      end Uses;
   begin
      return not Is_Null (Def)
        and then Def.Kind = Libadalang.Common.Ada_Derived_Type_Def
        and then Any_Node (Def, Uses'Access);
   end Is_Passed_To_Parent;

   procedure Analyze_Discriminants
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl  : constant Libadalang.Analysis.Type_Decl := Item.As_Type_Decl;
      Part  : constant Libadalang.Analysis.Discriminant_Part :=
        Decl.F_Discriminants;
      Specs : Libadalang.Analysis.Discriminant_Spec_List;
   begin
      if Is_Null (Part)
        or else Part.Kind /= Libadalang.Common.Ada_Known_Discriminant_Part
        or else (not Is_Null (Decl.F_Type_Def)
                 and then Decl.F_Type_Def.Kind =
                            Libadalang.Common.Ada_Private_Type_Def)
      then
         return;
      end if;

      --  A derived type that only forwards its discriminants to its
      --  parent adds no discriminated record of its own.
      Specs := Part.As_Known_Discriminant_Part.F_Discr_Specs;
      for I in 1 .. Specs.Children_Count loop
         declare
            Ids : constant Libadalang.Analysis.Defining_Name_List :=
              Specs.Child (I).As_Discriminant_Spec.F_Ids;
         begin
            for J in 1 .. Ids.Children_Count loop
               if not Is_Passed_To_Parent
                        (Ids.Child (J).As_Defining_Name.F_Name.As_Ada_Node,
                         Decl.F_Type_Def)
               then
                  Report_Rule_Violation
                    (Unit, Item, Discriminated_Record,
                     "discriminated record declared");
                  return;
               end if;
            end loop;
         end;
      end loop;
   end Analyze_Discriminants;

   ---------------------------
   --  Anonymous subtypes   --
   ---------------------------

   function Has_Range_Spec (Item : Node) return Boolean
   is (Item.Kind = Libadalang.Common.Ada_Range_Spec);

   --  True when a discriminant of Type_Decl is named in or below Item.
   function Uses_Discriminant_Of
     (Item : Libadalang.Analysis.Ada_Node'Class; Type_Decl : Node)
      return Boolean
   is
      Part : Libadalang.Analysis.Discriminant_Part;

      function Is_Discriminant_Name (Candidate : Node) return Boolean is
         Specs : constant Libadalang.Analysis.Discriminant_Spec_List :=
           Part.As_Known_Discriminant_Part.F_Discr_Specs;
      begin
         if Candidate.Kind /= Libadalang.Common.Ada_Identifier then
            return False;
         end if;

         for I in 1 .. Specs.Children_Count loop
            declare
               Ids : constant Libadalang.Analysis.Defining_Name_List :=
                 Specs.Child (I).As_Discriminant_Spec.F_Ids;
            begin
               for J in 1 .. Ids.Children_Count loop
                  if Same_Name
                       (Ids.Child (J).As_Defining_Name.F_Name, Candidate)
                  then
                     return True;
                  end if;
               end loop;
            end;
         end loop;
         return False;
      end Is_Discriminant_Name;
   begin
      if Is_Null (Type_Decl) then
         return False;
      end if;

      Part := Type_Decl.As_Type_Decl.F_Discriminants;
      if Is_Null (Part)
        or else Part.Kind /= Libadalang.Common.Ada_Known_Discriminant_Part
      then
         return False;
      end if;

      for I in 1 .. Item.Children_Count loop
         if Any_Node (Item.Child (I), Is_Discriminant_Name'Access) then
            return True;
         end if;
      end loop;
      return False;
   end Uses_Discriminant_Of;

   function Is_Constraint_Of_Indication (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Constraint);

   --  True when Item is a range or Range attribute standing where a
   --  subtype is expected: not the range of a type definition or of a
   --  component clause, and not part of a subtype indication's constraint.
   function Is_Free_Standing_Range
     (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Node := Item.Parent;
   begin
      if Current.Kind = Libadalang.Common.Ada_Range_Spec
        and then not Is_Null (Current.Parent)
        and then Current.Parent.Kind in Libadalang.Common.Ada_Type_Def
                   | Libadalang.Common.Ada_Component_Clause
      then
         return False;
      end if;

      while not Is_Null (Current) loop
         if Is_Constraint_Of_Indication (Current.Kind)
           and then not Is_Null (Current.Parent)
           and then Current.Parent.Kind in
                      Libadalang.Common.Ada_Subtype_Indication_Range
         then
            return False;
         end if;
         Current := Current.Parent;
      end loop;
      return True;
   end Is_Free_Standing_Range;

   procedure Analyze_Anonymous_Subtype
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind       : constant Node_Kind := Item.Kind;
      Type_Decl  : constant Node := Enclosing_Type (Item);
      Constraint : Libadalang.Analysis.Constraint;
   begin
      if Kind in Libadalang.Common.Ada_Subtype_Indication_Range then
         Constraint := Item.As_Subtype_Indication.F_Constraint;
         if Is_Null (Constraint) then
            return;
         end if;

         declare
            Composite     : constant Boolean :=
              Constraint.Kind = Libadalang.Common.Ada_Composite_Constraint;
            Discriminants : constant Boolean :=
              Composite
              and then Constraint.As_Composite_Constraint
                         .P_Is_Discriminant_Constraint;

            function Is_Access_To_Self (Candidate : Node) return Boolean
            is (Is_Attribute (Candidate, "access")
                and then Same_Name
                           (Candidate.As_Attribute_Ref.F_Prefix,
                            Type_Decl.As_Type_Decl.F_Name.F_Name));
         begin
            --  A discriminant constraint that refers to the enclosing
            --  type itself (a self-referencing component).
            if Discriminants
              and then not Is_Null (Type_Decl)
              and then not Is_Null (Type_Decl.As_Type_Decl.F_Name)
              and then (for some I in 1 .. Constraint.Children_Count =>
                          Any_Node
                            (Constraint.Child (I), Is_Access_To_Self'Access))
            then
               return;
            end if;

            --  The constraint of a subtype declaration names the subtype.
            if Item.Parent.Kind = Libadalang.Common.Ada_Subtype_Decl then
               if Constraint.Kind = Libadalang.Common.Ada_Range_Constraint
                 or else Discriminants
               then
                  return;
               elsif Composite then
                  declare
                     Assocs  : constant Libadalang.Analysis.Assoc_List :=
                       Constraint.As_Composite_Constraint.F_Constraints;
                     All_Types : Boolean := True;
                  begin
                     for I in 1 .. Assocs.Children_Count loop
                        if not Names_A_Type
                                 (Assocs.Child (I)
                                    .As_Composite_Constraint_Assoc
                                    .F_Constraint_Expr)
                        then
                           All_Types := False;
                        end if;
                     end loop;

                     if All_Types then
                        return;
                     end if;
                  end;
               end if;
            end if;
         end;
      elsif Kind = Libadalang.Common.Ada_Bin_Op then
         if Item.As_Bin_Op.F_Op.Kind /= Libadalang.Common.Ada_Op_Double_Dot
           or else not Is_Free_Standing_Range (Item)
         then
            return;
         end if;
      elsif not Is_Attribute (Item, "range")
        or else not Is_Free_Standing_Range (Item)
      then
         return;
      end if;

      if not Uses_Discriminant_Of (Item, Type_Decl) then
         Report_Rule_Violation
           (Unit, Item, Anonymous_Subtype, "anonymous subtype used");
      end if;
   end Analyze_Anonymous_Subtype;

   --------------------
   --  Real ranges   --
   --------------------

   function Is_Real_Without_Range
     (Decl : Libadalang.Analysis.Base_Type_Decl; Depth : Natural := 0)
      return Boolean
   is
      Def : Libadalang.Analysis.Type_Def;
   begin
      if Is_Null (Decl) or else Depth > 32 then
         return False;
      elsif Decl.Kind = Libadalang.Common.Ada_Subtype_Decl then
         return not Any_Node
                      (Decl.As_Subtype_Decl.F_Subtype.F_Constraint,
                       Has_Range_Spec'Access)
           and then Is_Real_Without_Range (Decl.P_Base_Subtype, Depth + 1);
      elsif Decl.Kind not in Libadalang.Common.Ada_Type_Decl then
         return False;
      end if;

      Def := Decl.As_Type_Decl.F_Type_Def;
      if Is_Null (Def) then
         return False;
      end if;

      case Def.Kind is
         when Libadalang.Common.Ada_Floating_Point_Def =>
            return Is_Null (Def.As_Floating_Point_Def.F_Range);
         when Libadalang.Common.Ada_Ordinary_Fixed_Point_Def =>
            return Is_Null (Def.As_Ordinary_Fixed_Point_Def.F_Range);
         when Libadalang.Common.Ada_Decimal_Fixed_Point_Def =>
            return Is_Null (Def.As_Decimal_Fixed_Point_Def.F_Range);
         when Libadalang.Common.Ada_Derived_Type_Def =>
            return not Any_Node
                         (Def.As_Derived_Type_Def.F_Subtype_Indication
                            .F_Constraint,
                          Has_Range_Spec'Access)
              and then Is_Real_Without_Range (Decl.P_Base_Type, Depth + 1);
         when others =>
            return False;
      end case;
   end Is_Real_Without_Range;

   procedure Analyze_Real_Type
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Item.As_Base_Type_Decl.P_Is_Real_Type
        and then Is_Real_Without_Range (Item.As_Base_Type_Decl)
      then
         Report_Rule_Violation
           (Unit, Item, No_Explicit_Real_Range,
            "real type declared without a range");
      end if;
   end Analyze_Real_Type;

   ---------------------------------
   --  Equality and membership    --
   ---------------------------------

   function Is_Listed_Object
     (Name : Libadalang.Analysis.Expr'Class; Actuals : String) return Boolean
   is
      Definition : Libadalang.Analysis.Defining_Name;
   begin
      if Name.Kind not in Libadalang.Common.Ada_Name then
         return False;
      end if;

      Definition := Name.As_Name.P_Referenced_Defining_Name;
      return not Is_Null (Definition)
        and then Definition.P_Basic_Decl.Kind in
                   Libadalang.Common.Ada_Object_Decl_Range
                   | Libadalang.Common.Ada_Number_Decl
                   | Libadalang.Common.Ada_Param_Spec
                   | Libadalang.Common.Ada_Generic_Formal_Obj_Decl
        and then Is_Listed
                   (Langkit_Support.Text.To_UTF8
                      (Definition.P_Canonical_Fully_Qualified_Name),
                    Actuals);
   exception
      when others =>
         return False;
   end Is_Listed_Object;

   procedure Analyze_Equality
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Operation : constant Libadalang.Analysis.Bin_Op := Item.As_Bin_Op;
      Actuals   : constant String :=
        Text_Parameter (Direct_Equality, "actuals");
      Decl      : Libadalang.Analysis.Basic_Decl;
   begin
      if Actuals = ""
        or else Operation.F_Op.Kind not in Libadalang.Common.Ada_Op_Eq
                  | Libadalang.Common.Ada_Op_Neq
      then
         return;
      end if;

      --  The left operand counts only under the predefined operator; the
      --  right operand counts under any.
      Decl := Operation.F_Op.P_Referenced_Decl;
      if ((Is_Null (Decl) or else Decl.P_Is_Predefined_Operator)
          and then Is_Listed_Object (Operation.F_Left, Actuals))
        or else Is_Listed_Object (Operation.F_Right, Actuals)
      then
         Report_Rule_Violation
           (Unit, Item, Direct_Equality,
            "direct equality test on a listed object");
      end if;
   end Analyze_Equality;

   procedure Analyze_Validity_Membership
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Test        : constant Libadalang.Analysis.Membership_Expr :=
        Item.As_Membership_Expr;
      Object_Decl : Node;
      Object_Type : Node := Libadalang.Analysis.No_Ada_Node;
      Choice      : Node;

      function Is_Object_Type
        (Name : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is (Names_A_Type (Name) and then Referenced (Name) = Object_Type);
   begin
      if Test.F_Expr.Kind not in Libadalang.Common.Ada_Name
        or else Test.F_Membership_Exprs.Children_Count /= 1
      then
         return;
      end if;

      Object_Decl := Referenced (Test.F_Expr);
      if not Is_Null (Object_Decl)
        and then Object_Decl.Kind in Libadalang.Common.Ada_Basic_Decl
      then
         declare
            Type_Ref : constant Libadalang.Analysis.Type_Expr :=
              Object_Decl.As_Basic_Decl.P_Type_Expression;
         begin
            if not Is_Null (Type_Ref) then
               Object_Type := Type_Ref.P_Designated_Type_Decl.As_Ada_Node;
            end if;
         end;
      end if;

      if Is_Null (Object_Type) then
         return;
      end if;

      Choice := Test.F_Membership_Exprs.Child (1);
      if (Choice.Kind in Libadalang.Common.Ada_Name
          and then Choice.Kind /= Libadalang.Common.Ada_Attribute_Ref
          and then Is_Object_Type (Choice))
        or else (Is_Attribute (Choice, "range")
                 and then Is_Object_Type (Choice.As_Attribute_Ref.F_Prefix))
        or else (Choice.Kind = Libadalang.Common.Ada_Bin_Op
                 and then Choice.As_Bin_Op.F_Op.Kind =
                            Libadalang.Common.Ada_Op_Double_Dot
                 and then Is_Attribute (Choice.As_Bin_Op.F_Left, "first")
                 and then Is_Attribute (Choice.As_Bin_Op.F_Right, "last")
                 and then Is_Object_Type
                            (Choice.As_Bin_Op.F_Left.As_Attribute_Ref.F_Prefix)
                 and then Is_Object_Type
                            (Choice.As_Bin_Op.F_Right.As_Attribute_Ref
                               .F_Prefix))
      then
         Report_Rule_Violation
           (Unit, Item, Membership_For_Validity,
            "membership test in the object's own subtype instead of Valid");
      end if;
   end Analyze_Validity_Membership;

   -----------------
   --  Generics   --
   -----------------

   function Instantiated_Generic
     (Item : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Decl : Node;
   begin
      if Item.Kind = Libadalang.Common.Ada_Generic_Package_Instantiation then
         Decl := Referenced
           (Item.As_Generic_Package_Instantiation.F_Generic_Pkg_Name);
      else
         Decl := Referenced
           (Item.As_Generic_Subp_Instantiation.F_Generic_Subp_Name);
      end if;

      for Step in 1 .. 8 loop
         exit when Is_Null (Decl)
           or else Decl.Kind not in Libadalang.Common.Ada_Generic_Renaming_Decl;
         if Decl.Kind = Libadalang.Common.Ada_Generic_Package_Renaming_Decl
         then
            Decl := Referenced
              (Decl.As_Generic_Package_Renaming_Decl.F_Renames);
         else
            Decl := Referenced (Decl.As_Generic_Subp_Renaming_Decl.F_Renames);
         end if;
      end loop;
      return Decl;
   end Instantiated_Generic;

   --  True when a chain of Depth further instantiations starts at Item:
   --  the generic Item instantiates itself contains an instantiation, and
   --  so on.
   function Has_Instantiation_Depth
     (Item : Libadalang.Analysis.Ada_Node'Class; Depth : Natural)
      return Boolean
   is
      function Continues (Candidate : Node) return Boolean
      is (Candidate.Kind in Libadalang.Common.Ada_Generic_Instantiation
          and then Has_Instantiation_Depth (Candidate, Depth - 1));
   begin
      return Depth = 0
        or else Any_Node (Instantiated_Generic (Item), Continues'Access);
   end Has_Instantiation_Depth;

   procedure Analyze_Generic_Association
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Assoc   : constant Libadalang.Analysis.Param_Assoc := Item.As_Param_Assoc;
      Generic_Unit : Node;
      Left    : Natural := 0;
   begin
      if not Is_Null (Assoc.F_Designator)
        or else Assoc.F_R_Expr.Kind = Libadalang.Common.Ada_Box_Expr
        or else Item.Parent.Kind /= Libadalang.Common.Ada_Assoc_List
        or else Item.Parent.Parent.Kind not in
                  Libadalang.Common.Ada_Generic_Instantiation
      then
         return;
      end if;

      for I in 1 .. Item.Parent.Children_Count loop
         Left := Left + 1;
         exit when Item.Parent.Child (I) = Item.As_Ada_Node;
      end loop;

      Generic_Unit := Instantiated_Generic (Item.Parent.Parent);
      if Is_Null (Generic_Unit)
        or else Generic_Unit.Kind not in Libadalang.Common.Ada_Generic_Decl
      then
         return;
      end if;

      declare
         Formals : constant Libadalang.Analysis.Ada_Node_List :=
           Generic_Unit.As_Generic_Decl.F_Formal_Part.F_Decls;
      begin
         for I in 1 .. Formals.Children_Count loop
            if Formals.Child (I).Kind in Libadalang.Common.Ada_Generic_Formal
            then
               declare
                  Formal : constant Libadalang.Analysis.Basic_Decl :=
                    Formals.Child (I).As_Generic_Formal.F_Decl;
                  Names  : constant Natural :=
                    (if Formal.Kind = Libadalang.Common.Ada_Object_Decl
                     then Formal.As_Object_Decl.F_Ids.Children_Count
                     elsif Formal.Kind = Libadalang.Common.Ada_Number_Decl
                     then Formal.As_Number_Decl.F_Ids.Children_Count
                     else 1);
               begin
                  if Left <= Names then
                     if (Formal.Kind = Libadalang.Common.Ada_Object_Decl
                         and then not Is_Null
                                        (Formal.As_Object_Decl.F_Default_Expr))
                       or else (Formal.Kind in
                                  Libadalang.Common.Ada_Formal_Subp_Decl
                                and then not Is_Null
                                               (Formal.As_Formal_Subp_Decl
                                                  .F_Default_Expr))
                     then
                        Report_Rule_Violation
                          (Unit, Item, Positional_Defaulted_Generic_Parameter,
                           "positional actual for a defaulted generic "
                           & "parameter");
                     end if;
                     return;
                  end if;
                  Left := Left - Names;
               end;
            end if;
         end loop;
      end;
   end Analyze_Generic_Association;

   --  True when the library item Item depends, through with clauses that
   --  name generic units, on a chain of Depth generic units.
   function Has_Generic_Dependency_Depth
     (Item : Node; Depth : Natural) return Boolean
   is
      Prelude : Libadalang.Analysis.Ada_Node_List;
   begin
      if Depth = 0 then
         return True;
      elsif Is_Null (Item)
        or else Item.Kind /= Libadalang.Common.Ada_Library_Item
        or else Is_Null (Item.Parent)
        or else Item.Parent.Kind /= Libadalang.Common.Ada_Compilation_Unit
      then
         return False;
      end if;

      Prelude := Item.Parent.As_Compilation_Unit.F_Prelude;
      for I in 1 .. Prelude.Children_Count loop
         if Prelude.Child (I).Kind = Libadalang.Common.Ada_With_Clause then
            declare
               Names : constant Libadalang.Analysis.Name_List :=
                 Prelude.Child (I).As_With_Clause.F_Packages;
            begin
               for J in 1 .. Names.Children_Count loop
                  declare
                     Decl : constant Node := Referenced (Names.Child (J));
                  begin
                     if not Is_Null (Decl)
                       and then Decl.Kind in Libadalang.Common.Ada_Generic_Decl
                       and then Has_Generic_Dependency_Depth
                                  (Decl.Parent, Depth - 1)
                     then
                        return True;
                     end if;
                  end;
               end loop;
            end;
         end if;
      end loop;
      return False;
   end Has_Generic_Dependency_Depth;

   procedure Analyze_With_Name
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl : constant Node := Referenced (Item);
   begin
      if not Is_Null (Decl)
        and then Decl.Kind in Libadalang.Common.Ada_Generic_Decl
        and then Has_Generic_Dependency_Depth
                   (Decl.Parent,
                    Config.Rule_Parameter
                      (Too_Many_Generic_Dependencies, "n", 3))
      then
         Report_Rule_Violation
           (Unit, Item, Too_Many_Generic_Dependencies,
            "unit depends on a chain of generic units that is too long");
      end if;
   end Analyze_With_Name;

   -------------------
   --  Exceptions   --
   -------------------

   function Is_Private_Part (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Private_Part);

   procedure Analyze_Raise
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Name     : constant Libadalang.Analysis.Name :=
        Item.As_Raise_Stmt.F_Exception_Name;
      Raised   : Node;
      Library  : Node := Item.Parent;
      Home     : Node;
      Current  : Node;
   begin
      if Is_Null (Name) then
         return;
      end if;

      while not Is_Null (Library)
        and then Library.Kind /= Libadalang.Common.Ada_Library_Item
      loop
         Library := Library.Parent;
      end loop;

      if Is_Null (Library) then
         return;
      end if;

      --  The library package whose visible part must declare the exception.
      Home := Library.As_Library_Item.F_Item.As_Ada_Node;
      if Home.Kind in Libadalang.Common.Ada_Base_Package_Decl then
         Home := Library;
      elsif Home.Kind = Libadalang.Common.Ada_Package_Body then
         Home := Home.As_Body_Node.P_Decl_Part.As_Ada_Node;
         Home := (if Is_Null (Home) then Home else Home.Parent);
      else
         return;
      end if;

      Raised := Referenced (Name);
      if Is_Null (Raised) then
         return;
      end if;

      declare
         Full_Name : constant String := Lower
           (Langkit_Support.Text.To_UTF8
              (Raised.As_Basic_Decl.P_Defining_Name
                 .P_Canonical_Fully_Qualified_Name));
      begin
         if Full_Name = "standard.program_error"
           or else Full_Name = "standard.constraint_error"
           or else Full_Name = "standard.numeric_error"
           or else Full_Name = "standard.storage_error"
           or else Full_Name = "standard.tasking_error"
         then
            return;
         end if;
      end;

      --  Handled in an enclosing handler of the same unit.
      Current := Item.Parent;
      while not Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Handled_Stmts then
            declare
               Handlers : constant Libadalang.Analysis.Ada_Node_List :=
                 Current.As_Handled_Stmts.F_Exceptions;
            begin
               for I in 1 .. Handlers.Children_Count loop
                  if Handlers.Child (I).Kind =
                       Libadalang.Common.Ada_Exception_Handler
                  then
                     declare
                        Choices : constant Libadalang.Analysis
                                             .Alternatives_List :=
                          Handlers.Child (I).As_Exception_Handler
                            .F_Handled_Exceptions;
                     begin
                        for J in 1 .. Choices.Children_Count loop
                           if Choices.Child (J).Kind =
                                Libadalang.Common.Ada_Others_Designator
                             or else Referenced (Choices.Child (J)) = Raised
                           then
                              return;
                           end if;
                        end loop;
                     end;
                  end if;
               end loop;
            end;
         end if;
         Current := Current.Parent;
      end loop;

      --  Declared in the visible part of the library package.
      if not Is_Null (Home)
        and then not Has_Ancestor (Raised, Is_Private_Part'Access)
      then
         Current := Raised.Parent;
         while not Is_Null (Current) loop
            if Current = Home then
               return;
            end if;
            Current := Current.Parent;
         end loop;
      end if;

      Report_Rule_Violation
        (Unit, Item, Raising_External_Exception,
         "raised exception is not declared in the visible part of the "
         & "enclosing library package");
   end Analyze_Raise;

   ---------------------------
   --  Object orientation   --
   ---------------------------

   function Tagged_Type_Of
     (Decl : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Base_Type_Decl
   is
      Spec : Libadalang.Analysis.Base_Subp_Spec;
   begin
      if Is_Null (Decl)
        or else Decl.Kind not in Libadalang.Common.Ada_Basic_Decl
      then
         return Libadalang.Analysis.No_Base_Type_Decl;
      end if;

      Spec := Decl.As_Basic_Decl.P_Subp_Spec_Or_Null;
      if Is_Null (Spec) then
         return Libadalang.Analysis.No_Base_Type_Decl;
      end if;
      return Spec.P_Primitive_Subp_Tagged_Type;
   end Tagged_Type_Of;

   procedure Analyze_Static_Call
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Callee   : Node;
      Owner    : Libadalang.Analysis.Base_Type_Decl;
      Current  : Node := Item.Parent;
   begin
      if not Item.As_Name.P_Is_Static_Call then
         return;
      end if;

      Callee := Referenced (Item);
      for Step in 1 .. 8 loop
         exit when Is_Null (Callee)
           or else Callee.Kind /= Libadalang.Common.Ada_Subp_Renaming_Decl;
         Callee := Referenced
           (Callee.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object);
      end loop;

      Owner := Tagged_Type_Of (Callee);
      if Is_Null (Owner)
        or else not Owner.P_Most_Visible_Part (Item).As_Base_Type_Decl
                      .P_Is_Tagged_Type
      then
         return;
      end if;

      --  A call to the parent type's operation from its own overriding is
      --  the usual way to extend it.
      while not Is_Null (Current)
        and then Current.Kind not in Libadalang.Common.Ada_Body_Node
      loop
         Current := Current.Parent;
      end loop;

      if not Is_Null (Current)
        and then Current.Kind in Libadalang.Common.Ada_Base_Subp_Body
        and then Same_Name
                   (Current.As_Basic_Decl.P_Defining_Name.F_Name,
                    Callee.As_Basic_Decl.P_Defining_Name.F_Name)
      then
         declare
            Caller_Type : constant Libadalang.Analysis.Base_Type_Decl :=
              Tagged_Type_Of (Current);
         begin
            if not Is_Null (Caller_Type) then
               for Parent of Caller_Type.P_Base_Types loop
                  if Parent.P_Full_View = Owner.P_Full_View then
                     return;
                  end if;
               end loop;
            end if;
         end;
      end if;

      Report_Rule_Violation
        (Unit, Item, Direct_Call_To_Primitive,
         "non-dispatching call to a primitive operation");
   end Analyze_Static_Call;

   function Is_Downward
     (From, To : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is (not Is_Null (From) and then not Is_Null (To)
       and then To.P_Full_View.P_Specific_Type /=
                  From.P_Full_View.P_Specific_Type
       and then To.P_Is_Derived_Type (From));

   procedure Analyze_View_Conversion
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Call    : constant Libadalang.Analysis.Call_Expr := Item.As_Call_Expr;
      Target  : constant Node := Referenced (Item);
      To_Type : Libadalang.Analysis.Base_Type_Decl;
      From    : Libadalang.Analysis.Base_Type_Decl;
   begin
      if Is_Null (Target)
        or else Target.Kind not in Libadalang.Common.Ada_Base_Type_Decl
        or else Call.F_Suffix.Kind /= Libadalang.Common.Ada_Assoc_List
        or else Call.F_Suffix.Children_Count = 0
      then
         return;
      end if;

      To_Type := Target.As_Base_Type_Decl.P_Base_Subtype;
      if Is_Null (To_Type)
        or else not (To_Type.P_Is_Tagged_Type
                     or else (not Is_Null (To_Type.P_Accessed_Type)
                              and then To_Type.P_Accessed_Type
                                         .P_Is_Tagged_Type))
      then
         return;
      end if;

      From := Call.F_Suffix.Child (1).As_Param_Assoc.F_R_Expr
        .P_Expression_Type;
      if Is_Null (From) then
         return;
      end if;
      From := From.P_Full_View;

      if Is_Downward (From, To_Type)
        or else Is_Downward (From.P_Accessed_Type, To_Type.P_Accessed_Type)
      then
         Report_Rule_Violation
           (Unit, Item, Downward_View_Conversion, "downward view conversion");
      end if;
   end Analyze_View_Conversion;

   function Has_Invariant
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is (not Is_Null (Type_Decl)
       and then (Has_Aspect (Type_Decl, "Type_Invariant")
                 or else (not Is_Null (Type_Decl.P_Previous_Part)
                          and then Has_Aspect
                                     (Type_Decl.P_Previous_Part,
                                      "Type_Invariant"))
                 or else (not Is_Null (Type_Decl.P_Full_View)
                          and then Has_Aspect
                                     (Type_Decl.P_Full_View,
                                      "Type_Invariant"))));

   procedure Analyze_Parent_Invariant
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Owner    : constant Node := Item.Parent;
      Previous : Libadalang.Analysis.Base_Type_Decl;
      Base     : Libadalang.Analysis.Base_Type_Decl;
   begin
      if Is_Null (Owner)
        or else Owner.Kind not in Libadalang.Common.Ada_Base_Type_Decl
        or else not Owner.As_Base_Type_Decl.P_Is_Tagged_Type
        or else Owner.Parent.Kind =
                  Libadalang.Common.Ada_Generic_Formal_Type_Decl
      then
         return;
      end if;

      --  The full view of a private extension is reported at the
      --  extension, not again here.
      Previous := Owner.As_Base_Type_Decl.P_Previous_Part;
      if not Is_Null (Previous)
        and then Previous.Kind in Libadalang.Common.Ada_Type_Decl
        and then not Is_Null (Previous.As_Type_Decl.F_Type_Def)
        and then Previous.As_Type_Decl.F_Type_Def.Kind =
                   Libadalang.Common.Ada_Derived_Type_Def
        and then Previous.As_Type_Decl.F_Type_Def.As_Derived_Type_Def
                   .F_Has_With_Private.P_As_Bool
      then
         return;
      end if;

      Base := Owner.As_Base_Type_Decl.P_Base_Type;
      for Step in 1 .. 16 loop
         exit when Is_Null (Base)
           or else Base.Kind /= Libadalang.Common.Ada_Subtype_Decl;
         Base := Base.P_Base_Subtype;
      end loop;

      if Is_Null (Base) then
         return;
      end if;

      if Has_Invariant (Base)
        or else (for some Ancestor of Base.P_Base_Types =>
                   Has_Invariant (Ancestor))
      then
         Report_Rule_Violation
           (Unit, Item, Specific_Parent_Type_Invariant,
            "parent type has a Type_Invariant aspect that is not "
            & "class-wide");
      end if;
   end Analyze_Parent_Invariant;

   procedure Analyze_Inherited_Precondition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Is_Null (Tagged_Type_Of (Item)) then
         return;
      end if;

      declare
         Overridden : constant Libadalang.Analysis.Basic_Decl_Array :=
           Item.As_Basic_Decl.P_Base_Subp_Declarations;
      begin
         if Overridden'Length <= 1 then
            return;
         end if;

         --  A root declaration of the operation without Pre'Class leaves
         --  the overriding with nothing to inherit.
         for Decl of Overridden loop
            if Decl.P_Base_Subp_Declarations'Length = 1
              and then not Has_Aspect (Decl, "Pre'Class")
            then
               Report_Rule_Violation
                 (Unit, Item.As_Basic_Decl.P_Defining_Name,
                  No_Inherited_Classwide_Pre,
                  "overriding operation does not inherit a Pre'Class");
               return;
            end if;
         end loop;
      end;
   end Analyze_Inherited_Precondition;

   procedure Analyze_Final_Parent
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Parent_Unit : constant Node := Item.P_Semantic_Parent;
   begin
      if Is_Null (Parent_Unit)
        or else Parent_Unit.Kind not in Libadalang.Common.Ada_Base_Package_Decl
      then
         return;
      end if;

      declare
         Annotation : constant Libadalang.Analysis.Aspect :=
           Parent_Unit.As_Basic_Decl.P_Get_Aspect (Aspect_Name ("Annotate"));
      begin
         if not Libadalang.Analysis.Exists (Annotation) then
            return;
         end if;

         declare
            Value : constant Node :=
              Libadalang.Analysis.Value (Annotation).As_Ada_Node;
         begin
            if not Is_Null (Value)
              and then Value.Kind in Libadalang.Common.Ada_Aggregate
                         | Libadalang.Common.Ada_Bracket_Aggregate
              and then Value.As_Base_Aggregate.F_Assocs.Children_Count >= 2
              and then Canonical_Text
                         (Value.As_Base_Aggregate.F_Assocs.Child (1)) =
                       "gnatcheck"
              and then Canonical_Text
                         (Value.As_Base_Aggregate.F_Assocs.Child (2)) =
                       "final"
            then
               Report_Rule_Violation
                 (Unit, Item, Final_Package,
                  "child package of a package annotated as final");
            end if;
         end;
      end;
   end Analyze_Final_Parent;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Subtype_Indication_Range
           | Libadalang.Common.Ada_Bin_Op
           | Libadalang.Common.Ada_Attribute_Ref
      then
         Guarded
           (Unit, Node, On (Anonymous_Subtype),
            Analyze_Anonymous_Subtype'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Bin_Op
           | Libadalang.Common.Ada_Relation_Op
      then
         Guarded (Unit, Node, On (Direct_Equality), Analyze_Equality'Access);
      elsif Kind = Libadalang.Common.Ada_Membership_Expr then
         Guarded
           (Unit, Node, On (Membership_For_Validity),
            Analyze_Validity_Membership'Access);
      elsif Kind in Libadalang.Common.Ada_Type_Decl then
         Guarded
           (Unit, Node, On (Discriminated_Record),
            Analyze_Discriminants'Access);
         Guarded
           (Unit, Node, On (No_Explicit_Real_Range), Analyze_Real_Type'Access);
      elsif Kind = Libadalang.Common.Ada_Derived_Type_Def then
         Guarded
           (Unit, Node, On (Specific_Parent_Type_Invariant),
            Analyze_Parent_Invariant'Access);
      elsif Kind = Libadalang.Common.Ada_Param_Assoc then
         Guarded
           (Unit, Node, On (Positional_Defaulted_Generic_Parameter),
            Analyze_Generic_Association'Access);
      elsif Kind in Libadalang.Common.Ada_Generic_Instantiation then
         if On (Deeply_Nested_Instantiation) then
            begin
               if Has_Instantiation_Depth
                    (Node,
                     Config.Rule_Parameter
                       (Deeply_Nested_Instantiation, "n", 3))
               then
                  Report_Rule_Violation
                    (Unit, Node, Deeply_Nested_Instantiation,
                     "instantiation of a generic that is itself built on "
                     & "nested instantiations");
               end if;
            exception
               when Exc : others =>
                  Note_Skipped_Check (Node, Exc);
            end;
         end if;
      elsif Kind = Libadalang.Common.Ada_Raise_Stmt then
         Guarded
           (Unit, Node, On (Raising_External_Exception), Analyze_Raise'Access);
      elsif Kind = Libadalang.Common.Ada_Call_Expr then
         Guarded
           (Unit, Node, On (Downward_View_Conversion),
            Analyze_View_Conversion'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Base_Id then
         Guarded
           (Unit, Node, On (Direct_Call_To_Primitive),
            Analyze_Static_Call'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Name
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then not Libadalang.Analysis.Is_Null (Node.Parent.Parent)
        and then Node.Parent.Parent.Kind = Libadalang.Common.Ada_With_Clause
      then
         Guarded
           (Unit, Node, On (Too_Many_Generic_Dependencies),
            Analyze_With_Name'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Basic_Subp_Decl
           | Libadalang.Common.Ada_Base_Subp_Body
      then
         Guarded
           (Unit, Node, On (No_Inherited_Classwide_Pre),
            Analyze_Inherited_Precondition'Access);
      elsif Kind in Libadalang.Common.Ada_Base_Package_Decl
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind = Libadalang.Common.Ada_Library_Item
      then
         Guarded (Unit, Node, On (Final_Package), Analyze_Final_Parent'Access);
      end if;
   end Analyze_Node;

end Adalang_Analyzer.Checks.Design_Policy;
