--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with GNATCOLL.GMP.Integers;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text; use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Config;
with Adalang_Analyzer.Rules;    use Adalang_Analyzer.Rules;

package body Adalang_Analyzer.Checks.Suggestions is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Defining_Name;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;

   subtype Node is Libadalang.Analysis.Ada_Node;

   function Is_Null (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
     renames Libadalang.Analysis.Is_Null;

   --  True when Left and Right are the same simple or expanded name. Other
   --  forms of name, such as an indexed component, never match.
   function Same_Name
     (Left, Right : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (not Is_Null (Left) and then not Is_Null (Right)
       and then Left.Kind in Libadalang.Common.Ada_Base_Id
                  | Libadalang.Common.Ada_Dotted_Name
       and then Right.Kind in Libadalang.Common.Ada_Base_Id
                  | Libadalang.Common.Ada_Dotted_Name
       and then Canonical_Text (Left) = Canonical_Text (Right));

   function Is_Predefined
     (Op : Libadalang.Analysis.Name'Class) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl := Op.P_Referenced_Decl;
   begin
      return Is_Null (Decl) or else Decl.P_Is_Predefined_Operator;
   end Is_Predefined;

   --  Calls Visit on Item and on every node below it.
   procedure For_Each
     (Item  : Libadalang.Analysis.Ada_Node'Class;
      Visit : not null access procedure (Item : Node))
   is
   begin
      Visit (Item.As_Ada_Node);
      for I in 1 .. Item.Children_Count loop
         if not Is_Null (Item.Child (I)) then
            For_Each (Item.Child (I), Visit);
         end if;
      end loop;
   end For_Each;

   --  The number of identifiers below Item that spell the name of Target,
   --  optionally only those that are written to.
   function Count_References
     (Item        : Libadalang.Analysis.Ada_Node'Class;
      Target      : Libadalang.Analysis.Ada_Node'Class;
      Writes_Only : Boolean := False;
      Last        : access Node := null) return Natural
   is
      Total : Natural := 0;

      procedure Visit (Candidate : Node) is
      begin
         if Candidate.Kind = Libadalang.Common.Ada_Identifier
           and then Same_Name (Candidate, Target)
           and then (not Writes_Only
                     or else Candidate.As_Identifier.P_Is_Write_Reference)
         then
            Total := Total + 1;
            if Last /= null then
               Last.all := Candidate;
            end if;
         end if;
      end Visit;
   begin
      if not Is_Null (Item) then
         For_Each (Item, Visit'Access);
      end if;
      return Total;
   end Count_References;

   procedure Analyze_While_Loop
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Stmt      : constant Libadalang.Analysis.Base_Loop_Stmt :=
        Item.As_Base_Loop_Stmt;
      Condition : Libadalang.Analysis.Expr;
   begin
      if Is_Null (Stmt.F_Spec)
        or else Stmt.F_Spec.Kind /= Libadalang.Common.Ada_While_Loop_Spec
      then
         return;
      end if;
      Condition := Stmt.F_Spec.As_While_Loop_Spec.F_Expr;

      if On (Use_Simple_Loop)
        and then Condition.P_Is_Static_Expr
        and then GNATCOLL.GMP.Integers.Image (Condition.P_Eval_As_Int) = "1"
      then
         Report_Finding
           (Unit, Item, Use_Simple_Loop,
            "while loop with a condition that is always true can be a "
            & "plain loop");
      end if;

      if not On (Use_For_Loop)
        or else Condition.Kind /= Libadalang.Common.Ada_Relation_Op
        or else Condition.As_Relation_Op.F_Left.Kind /=
                  Libadalang.Common.Ada_Identifier
        or else not Is_Predefined (Condition.As_Relation_Op.F_Op)
      then
         return;
      end if;

      declare
         Counter : constant Libadalang.Analysis.Expr :=
           Condition.As_Relation_Op.F_Left;
         Write   : aliased Node := Libadalang.Analysis.No_Ada_Node;
         Assign  : Node;
         Step    : Libadalang.Analysis.Expr;
         Decl    : Libadalang.Analysis.Basic_Decl;
         Scope   : Node;
         Later   : Node;
      begin
         if Count_References
              (Stmt.F_Stmts, Counter, Writes_Only => True,
               Last => Write'Access) /= 1
         then
            return;
         end if;

         --  The single write must be "Counter := Counter +/- 1;" as the
         --  last statement of the loop body.
         Assign := Write.Parent;
         if Is_Null (Assign)
           or else Assign.Kind /= Libadalang.Common.Ada_Assign_Stmt
           or else Assign.Parent /= Stmt.F_Stmts.As_Ada_Node
           or else not Is_Null (Assign.Next_Sibling)
         then
            return;
         end if;

         Step := Assign.As_Assign_Stmt.F_Expr;
         if Step.Kind /= Libadalang.Common.Ada_Bin_Op
           or else Step.As_Bin_Op.F_Op.Kind not in
                     Libadalang.Common.Ada_Op_Plus
                     | Libadalang.Common.Ada_Op_Minus
           or else not Is_Predefined (Step.As_Bin_Op.F_Op)
           or else Step.As_Bin_Op.F_Right.Kind /=
                     Libadalang.Common.Ada_Int_Literal
           or else Node_Text (Step.As_Bin_Op.F_Right) /= "1"
           or else Step.As_Bin_Op.F_Left.Kind /=
                     Libadalang.Common.Ada_Identifier
           or else not Same_Name (Step.As_Bin_Op.F_Left, Counter)
         then
            return;
         end if;

         --  The counter must be a variable of the scope that holds the
         --  loop, never written in its declarative part and not used
         --  after the loop.
         Decl := Counter.As_Identifier.P_Referenced_Decl;
         if Is_Null (Decl)
           or else Decl.Kind not in Libadalang.Common.Ada_Object_Decl_Range
         then
            return;
         end if;

         Scope := Item.P_Semantic_Parent;
         while not Is_Null (Scope)
           and then Scope.Kind = Libadalang.Common.Ada_Named_Stmt
         loop
            Scope := Scope.P_Semantic_Parent;
         end loop;

         if Scope /= Decl.P_Semantic_Parent
           or else Count_References
                     (Decl.Parent, Counter, Writes_Only => True) > 0
         then
            return;
         end if;

         Later := Item.Next_Sibling;
         while not Is_Null (Later) loop
            if Count_References (Later, Counter) > 0 then
               return;
            end if;
            Later := Later.Next_Sibling;
         end loop;

         if Is_Set (Use_For_Loop, "no_exit") then
            declare
               Has_Exit : Boolean := False;

               procedure Visit (Candidate : Node) is
               begin
                  if Candidate.Kind = Libadalang.Common.Ada_Exit_Stmt then
                     Has_Exit := True;
                  end if;
               end Visit;
            begin
               For_Each (Stmt.F_Stmts, Visit'Access);
               if Has_Exit then
                  return;
               end if;
            end;
         end if;

         Report_Finding
           (Unit, Item, Use_For_Loop,
            "while loop over a counter can be a for loop");
      end;
   end Analyze_While_Loop;

   procedure Analyze_Plain_Loop
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Stmt  : constant Libadalang.Analysis.Base_Loop_Stmt :=
        Item.As_Base_Loop_Stmt;
      First : Node;
   begin
      if Stmt.F_Stmts.Children_Count = 0 then
         return;
      end if;

      First := Stmt.F_Stmts.Child (1);
      if First.Kind = Libadalang.Common.Ada_Exit_Stmt
        and then (Is_Null (First.As_Exit_Stmt.F_Loop_Name)
                  or else (not Is_Null (Stmt.F_End_Name)
                           and then Same_Name
                                      (Stmt.F_End_Name.F_Name,
                                       First.As_Exit_Stmt.F_Loop_Name)))
      then
         Report_Finding
           (Unit, Item, Use_While_Loop,
            "loop that starts with an exit can be a while loop");
      end if;
   end Analyze_Plain_Loop;

   function Is_Array_Index
     (Item : Libadalang.Analysis.Ada_Node'Class;
      Var  : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Item.Kind /= Libadalang.Common.Ada_Call_Expr
        or else Item.As_Call_Expr.F_Suffix.Kind /=
                  Libadalang.Common.Ada_Assoc_List
        or else Item.As_Call_Expr.F_Suffix.Children_Count /= 1
      then
         return False;
      end if;

      declare
         Index : constant Libadalang.Analysis.Expr :=
           Item.As_Call_Expr.F_Suffix.Child (1).As_Param_Assoc.F_R_Expr;
      begin
         return Index.Kind = Libadalang.Common.Ada_Identifier
           and then Same_Name (Index, Var)
           and then Item.As_Call_Expr.P_Kind = Libadalang.Common.Array_Index;
      end;
   end Is_Array_Index;

   function Array_Dimensions
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl) return Natural
   is
      Def : Libadalang.Analysis.Type_Def;
   begin
      if Is_Null (Type_Decl)
        or else Type_Decl.Kind not in Libadalang.Common.Ada_Type_Decl
      then
         return 0;
      end if;

      Def := Type_Decl.As_Type_Decl.F_Type_Def;
      if Is_Null (Def) then
         return 0;
      elsif Def.Kind = Libadalang.Common.Ada_Derived_Type_Def then
         return Array_Dimensions (Type_Decl.P_Base_Type);
      elsif Def.Kind /= Libadalang.Common.Ada_Array_Type_Def then
         return 0;
      end if;

      declare
         Indices : constant Libadalang.Analysis.Array_Indices :=
           Def.As_Array_Type_Def.F_Indices;
      begin
         return (if Indices.Kind =
                      Libadalang.Common.Ada_Constrained_Array_Indices
                 then Indices.As_Constrained_Array_Indices.F_List
                        .Children_Count
                 else Indices.As_Unconstrained_Array_Indices.F_Types
                        .Children_Count);
      end;
   end Array_Dimensions;

   function Is_Same_Object
     (Left, Right : Libadalang.Analysis.Name'Class) return Boolean
   is
      Definition : constant Libadalang.Analysis.Defining_Name :=
        Left.P_Referenced_Defining_Name;
      Decl       : Libadalang.Analysis.Basic_Decl;
   begin
      if Is_Null (Definition)
        or else Definition /= Right.P_Referenced_Defining_Name
      then
         return False;
      end if;

      Decl := Definition.P_Basic_Decl;
      if Decl.Kind in Libadalang.Common.Ada_Param_Spec
           | Libadalang.Common.Ada_Object_Decl_Range
      then
         return True;
      end if;

      return Decl.Kind = Libadalang.Common.Ada_Component_Decl
        and then Left.Kind = Libadalang.Common.Ada_Dotted_Name
        and then Right.Kind = Libadalang.Common.Ada_Dotted_Name
        and then Is_Same_Object
                   (Left.As_Dotted_Name.F_Prefix,
                    Right.As_Dotted_Name.F_Prefix);
   end Is_Same_Object;

   --  True when the bounds of component Comp may change with a
   --  discriminant that has a default, so that iterating over it by
   --  element is not equivalent to indexing it.
   function Depends_On_Mutable_Discriminant
     (Comp : Libadalang.Analysis.Basic_Decl) return Boolean
   is
      Found : Boolean := False;

      procedure Visit (Candidate : Node) is
         Decl : Libadalang.Analysis.Basic_Decl;
      begin
         if Candidate.Kind = Libadalang.Common.Ada_Identifier then
            Decl := Candidate.As_Identifier.P_Referenced_Decl;
            if not Is_Null (Decl)
              and then Decl.Kind = Libadalang.Common.Ada_Discriminant_Spec
              and then not Is_Null (Decl.As_Discriminant_Spec.F_Default_Expr)
            then
               Found := True;
            end if;
         end if;
      exception
         when Exc : others =>
            Note_Skipped_Check (Candidate, Exc);
      end Visit;

      Current : Node := Comp.Parent;
   begin
      For_Each
        (Comp.As_Component_Decl.F_Component_Def.F_Type_Expr, Visit'Access);

      while not Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Variant_Part then
            Visit (Current.As_Variant_Part.F_Discr_Name.As_Ada_Node);
         end if;
         Current := Current.Parent;
      end loop;
      return Found;
   end Depends_On_Mutable_Discriminant;

   --  Use_Array_Slice and Use_For_Of_Loop.
   procedure Analyze_For_Loop
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Stmt : constant Libadalang.Analysis.Base_Loop_Stmt :=
        Item.As_Base_Loop_Stmt;
      Spec : Libadalang.Analysis.For_Loop_Spec;
      Var  : Libadalang.Analysis.Name;
   begin
      if Is_Null (Stmt.F_Spec)
        or else Stmt.F_Spec.Kind /= Libadalang.Common.Ada_For_Loop_Spec
      then
         return;
      end if;
      Spec := Stmt.F_Spec.As_For_Loop_Spec;
      Var := Spec.F_Var_Decl.F_Id.F_Name;

      if On (Use_Array_Slice)
        and then Stmt.F_Stmts.Children_Count = 1
        and then Stmt.F_Stmts.Child (1).Kind =
                   Libadalang.Common.Ada_Assign_Stmt
      then
         declare
            Assign : constant Libadalang.Analysis.Assign_Stmt :=
              Stmt.F_Stmts.Child (1).As_Assign_Stmt;
         begin
            if Is_Array_Index (Assign.F_Dest, Var)
              and then (Assign.F_Expr.P_Is_Static_Expr
                        or else Is_Array_Index (Assign.F_Expr, Var))
            then
               Report_Finding
                 (Unit, Item, Use_Array_Slice,
                  "for loop can be an array slice assignment");
            end if;
         end;
      end if;

      if not On (Use_For_Of_Loop)
        or else Spec.F_Has_Reverse.Kind = Libadalang.Common.Ada_Reverse_Present
        or else Spec.F_Loop_Type.Kind /= Libadalang.Common.Ada_Iter_Type_In
        or else Spec.F_Iter_Expr.Kind /= Libadalang.Common.Ada_Attribute_Ref
        or else Canonical_Text
                  (Spec.F_Iter_Expr.As_Attribute_Ref.F_Attribute) /= "range"
      then
         return;
      end if;

      declare
         Prefix      : constant Libadalang.Analysis.Name :=
           Spec.F_Iter_Expr.As_Attribute_Ref.F_Prefix;
         Prefix_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Prefix.P_Expression_Type;
         Uses        : Natural := 0;
         Only_Index  : Boolean := True;

         procedure Visit (Candidate : Node) is
            Call : Node;
         begin
            if Candidate.Kind /= Libadalang.Common.Ada_Identifier
              or else not Same_Name (Candidate, Var)
            then
               return;
            end if;

            Uses := Uses + 1;
            if Candidate.Parent.Kind = Libadalang.Common.Ada_Param_Assoc
              and then Candidate.Parent.Parent.Kind =
                         Libadalang.Common.Ada_Assoc_List
              and then Candidate.Parent.Parent.Parent.Kind =
                         Libadalang.Common.Ada_Call_Expr
            then
               Call := Candidate.Parent.Parent.Parent;
               if not Is_Same_Object (Call.As_Call_Expr.F_Name, Prefix) then
                  Only_Index := False;
               end if;
            else
               Only_Index := False;
            end if;
         end Visit;
      begin
         if Is_Null (Prefix_Type)
           or else Prefix_Type.Kind not in Libadalang.Common.Ada_Type_Decl
           or else not Prefix_Type.P_Is_Array_Type
           or else Array_Dimensions (Prefix_Type) /= 1
         then
            return;
         end if;

         For_Each (Stmt.F_Stmts, Visit'Access);
         if not Only_Index
           or else Uses < Config.Rule_Parameter (Use_For_Of_Loop, "n", 1)
         then
            return;
         end if;

         declare
            Decl   : constant Libadalang.Analysis.Basic_Decl :=
              Prefix.P_Referenced_Decl;
            Holder : Libadalang.Analysis.Name := Prefix;
         begin
            if not Is_Null (Decl)
              and then Decl.Kind = Libadalang.Common.Ada_Component_Decl
            then
               while Holder.Kind = Libadalang.Common.Ada_Dotted_Name
                 and then Holder.P_Referenced_Decl.Kind =
                            Libadalang.Common.Ada_Component_Decl
               loop
                  Holder := Holder.As_Dotted_Name.F_Prefix;
               end loop;

               if not Holder.P_Referenced_Decl.P_Is_Constant_Object
                 and then Depends_On_Mutable_Discriminant (Decl)
               then
                  return;
               end if;
            end if;
         end;

         Report_Finding
           (Unit, Item, Use_For_Of_Loop,
            "for loop over an array's index range can be a for-of loop");
      end;
   end Analyze_For_Loop;

   --  The two forms Use_Range reports: T'Range where T alone would do,
   --  and X'First .. X'Last.
   procedure Analyze_Range
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Item.Kind;
   begin
      if Kind = Libadalang.Common.Ada_Attribute_Ref then
         if Canonical_Text (Item.As_Attribute_Ref.F_Attribute) /= "range"
           or else not (Item.Parent.Kind in
                          Libadalang.Common.Ada_For_Loop_Spec
                          | Libadalang.Common.Ada_Expr_Alternatives_List
                        or else (Item.Parent.Kind =
                                   Libadalang.Common.Ada_Alternatives_List
                                 and then Item.Parent.Parent.Kind in
                                            Libadalang.Common
                                              .Ada_Case_Stmt_Alternative
                                            | Libadalang.Common
                                                .Ada_Case_Expr_Alternative))
         then
            return;
         end if;

         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Item.As_Attribute_Ref.F_Prefix.P_Referenced_Decl;
         begin
            if Is_Null (Decl)
              or else Decl.Kind not in Libadalang.Common.Ada_Base_Type_Decl
              or else not Decl.As_Base_Type_Decl.P_Is_Discrete_Type
            then
               return;
            end if;
         end;
      else
         declare
            Operation : constant Libadalang.Analysis.Bin_Op := Item.As_Bin_Op;
         begin
            if Operation.F_Op.Kind /= Libadalang.Common.Ada_Op_Double_Dot
              or else Operation.F_Left.Kind /=
                        Libadalang.Common.Ada_Attribute_Ref
              or else Operation.F_Right.Kind /=
                        Libadalang.Common.Ada_Attribute_Ref
              or else Canonical_Text
                        (Operation.F_Left.As_Attribute_Ref.F_Attribute) /=
                      "first"
              or else Canonical_Text
                        (Operation.F_Right.As_Attribute_Ref.F_Attribute) /=
                      "last"
              or else not Same_Name
                            (Operation.F_Left.As_Attribute_Ref.F_Prefix,
                             Operation.F_Right.As_Attribute_Ref.F_Prefix)
            then
               return;
            end if;
         end;
      end if;

      Report_Finding
        (Unit, Item, Use_Range,
         "range can be written as a subtype mark or a Range attribute");
   end Analyze_Range;

   --  The first variable tested in Item: the left operand of a relation
   --  or the tested expression of a membership test, when an identifier.
   function First_Tested_Name
     (Item : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Result : Node := Libadalang.Analysis.No_Ada_Node;

      procedure Visit (Candidate : Node) is
      begin
         if not Is_Null (Result) then
            return;
         elsif Candidate.Kind = Libadalang.Common.Ada_Relation_Op
           and then Candidate.As_Relation_Op.F_Left.Kind =
                      Libadalang.Common.Ada_Identifier
         then
            Result := Candidate.As_Relation_Op.F_Left.As_Ada_Node;
         elsif Candidate.Kind = Libadalang.Common.Ada_Membership_Expr
           and then Candidate.As_Membership_Expr.F_Expr.Kind =
                      Libadalang.Common.Ada_Identifier
         then
            Result := Candidate.As_Membership_Expr.F_Expr.As_Ada_Node;
         end if;
      end Visit;
   begin
      For_Each (Item, Visit'Access);
      return Result;
   end First_Tested_Name;

   --  True when Item only compares Id with values: alternatives joined by
   --  "or", each an equality, a membership test, or a ">= .. and <= .."
   --  pair on Id.
   function Is_Membership_Shape
     (Item          : Libadalang.Analysis.Expr'Class;
      Id            : Node;
      Short_Circuit : Boolean) return Boolean
   is
      Kind : constant Node_Kind := Item.Kind;
   begin
      if Kind = Libadalang.Common.Ada_Paren_Expr then
         return Is_Membership_Shape
           (Item.As_Paren_Expr.F_Expr, Id, Short_Circuit);
      elsif Kind = Libadalang.Common.Ada_Membership_Expr then
         return Item.As_Membership_Expr.F_Op.Kind = Libadalang.Common.Ada_Op_In
           and then Same_Name (Item.As_Membership_Expr.F_Expr, Id);
      elsif Kind = Libadalang.Common.Ada_Relation_Op then
         return Item.As_Relation_Op.F_Op.Kind = Libadalang.Common.Ada_Op_Eq
           and then Item.As_Relation_Op.F_Left.Kind in Libadalang.Common.Ada_Name
           and then Same_Name (Item.As_Relation_Op.F_Left, Id)
           and then Is_Predefined (Item.As_Relation_Op.F_Op);
      elsif Kind /= Libadalang.Common.Ada_Bin_Op then
         return False;
      end if;

      declare
         Operation : constant Libadalang.Analysis.Bin_Op := Item.As_Bin_Op;
         Op        : constant Node_Kind := Operation.F_Op.Kind;
      begin
         if Op = Libadalang.Common.Ada_Op_Or
           or else (Short_Circuit
                    and then Op = Libadalang.Common.Ada_Op_Or_Else)
         then
            return Is_Predefined (Operation.F_Op)
              and then Is_Membership_Shape
                         (Operation.F_Left, Id, Short_Circuit)
              and then Is_Membership_Shape
                         (Operation.F_Right, Id, Short_Circuit);
         elsif Op = Libadalang.Common.Ada_Op_And
           or else (Short_Circuit
                    and then Op = Libadalang.Common.Ada_Op_And_Then)
         then
            return Is_Predefined (Operation.F_Op)
              and then Operation.F_Left.Kind =
                         Libadalang.Common.Ada_Relation_Op
              and then Operation.F_Right.Kind =
                         Libadalang.Common.Ada_Relation_Op
              and then Operation.F_Left.As_Relation_Op.F_Op.Kind =
                         Libadalang.Common.Ada_Op_Gte
              and then Operation.F_Right.As_Relation_Op.F_Op.Kind =
                         Libadalang.Common.Ada_Op_Lte
              and then Operation.F_Left.As_Relation_Op.F_Left.Kind =
                         Libadalang.Common.Ada_Identifier
              and then Operation.F_Right.As_Relation_Op.F_Left.Kind =
                         Libadalang.Common.Ada_Identifier
              and then Same_Name (Operation.F_Left.As_Relation_Op.F_Left, Id)
              and then Same_Name (Operation.F_Right.As_Relation_Op.F_Left, Id)
              and then Is_Predefined (Operation.F_Left.As_Relation_Op.F_Op)
              and then Is_Predefined (Operation.F_Right.As_Relation_Op.F_Op);
         end if;
         return False;
      end;
   end Is_Membership_Shape;

   procedure Analyze_Condition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Operation     : constant Libadalang.Analysis.Bin_Op := Item.As_Bin_Op;
      Op            : constant Node_Kind := Operation.F_Op.Kind;
      Short_Circuit : constant Boolean :=
        Is_Set (Use_Membership, "short_circuit");
      Id            : Node;
   begin
      if Item.Parent.Kind in Libadalang.Common.Ada_Expr
        or else not (Op in Libadalang.Common.Ada_Op_Or
                       | Libadalang.Common.Ada_Op_And
                     or else (Short_Circuit
                              and then Op in Libadalang.Common.Ada_Op_Or_Else
                                         | Libadalang.Common.Ada_Op_And_Then))
        or else not Is_Predefined (Operation.F_Op)
      then
         return;
      end if;

      Id := First_Tested_Name (Item);
      if not Is_Null (Id)
        and then Is_Membership_Shape (Operation, Id, Short_Circuit)
      then
         Report_Finding
           (Unit, Item, Use_Membership,
            "condition can be written as a membership test");
      end if;
   end Analyze_Condition;

   function Is_Single
     (Stmts : Libadalang.Analysis.Stmt_List'Class; Kind : Node_Kind)
      return Boolean
   is (not Is_Null (Stmts)
       and then Stmts.Children_Count = 1
       and then Stmts.Child (1).Kind = Kind
       and then (Kind /= Libadalang.Common.Ada_Assign_Stmt
                 or else Stmts.Child (1).As_Assign_Stmt.F_Dest.Kind in
                           Libadalang.Common.Ada_Name));

   --  True when every branch of Stmt, including a mandatory else, holds
   --  one statement of kind Kind.
   function All_Branches_Are
     (Stmt : Libadalang.Analysis.If_Stmt; Kind : Node_Kind) return Boolean
   is
   begin
      if Is_Null (Stmt.F_Else_Part)
        or else not Is_Single (Stmt.F_Then_Stmts, Kind)
        or else not Is_Single (Stmt.F_Else_Part.F_Stmts, Kind)
      then
         return False;
      end if;

      for I in 1 .. Stmt.F_Alternatives.Children_Count loop
         if not Is_Single
                  (Stmt.F_Alternatives.Child (I).As_Elsif_Stmt_Part.F_Stmts,
                   Kind)
         then
            return False;
         end if;
      end loop;
      return True;
   end All_Branches_Are;

   function Is_Static_Relation
     (Item : Libadalang.Analysis.Expr'Class) return Boolean
   is (Item.Kind = Libadalang.Common.Ada_Relation_Op
       and then Item.As_Relation_Op.F_Right.P_Is_Static_Expr
       and then Is_Predefined (Item.As_Relation_Op.F_Op));

   --  Use_If_Expression and Use_Case_Statement.
   procedure Analyze_If
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Stmt : constant Libadalang.Analysis.If_Stmt := Item.As_If_Stmt;
   begin
      if On (Use_If_Expression) then
         if All_Branches_Are (Stmt, Libadalang.Common.Ada_Return_Stmt) then
            Report_Finding
              (Unit, Item, Use_If_Expression,
               "if statement can be an if expression");
         elsif All_Branches_Are (Stmt, Libadalang.Common.Ada_Assign_Stmt) then
            declare
               Target : Node := Libadalang.Analysis.No_Ada_Node;
               Same   : Boolean := True;

               procedure Visit (Candidate : Node) is
               begin
                  if Candidate.Kind = Libadalang.Common.Ada_Assign_Stmt then
                     if Is_Null (Target) then
                        Target := Candidate.As_Assign_Stmt.F_Dest.As_Ada_Node;
                     elsif not Same_Name
                                 (Candidate.As_Assign_Stmt.F_Dest, Target)
                     then
                        Same := False;
                     end if;
                  end if;
               end Visit;
            begin
               For_Each (Item, Visit'Access);
               if Same then
                  Report_Finding
                    (Unit, Item, Use_If_Expression,
                     "if statement can be an if expression");
               end if;
            end;
         end if;
      end if;

      if not On (Use_Case_Statement)
        or else Stmt.F_Alternatives.Children_Count = 0
        or else not Is_Static_Relation (Stmt.F_Cond_Expr)
      then
         return;
      end if;

      declare
         Subject : constant Libadalang.Analysis.Expr :=
           Stmt.F_Cond_Expr.As_Relation_Op.F_Left;
         Subject_Type : Libadalang.Analysis.Base_Type_Decl;
      begin
         if Subject.Kind = Libadalang.Common.Ada_Identifier then
            Subject_Type := Subject.P_Expression_Type;
         elsif Subject.Kind = Libadalang.Common.Ada_Dotted_Name
           and then Subject.As_Dotted_Name.F_Suffix.P_Referenced_Decl.Kind =
                      Libadalang.Common.Ada_Component_Decl
         then
            Subject_Type :=
              Subject.As_Dotted_Name.F_Suffix.P_Expression_Type;
         else
            return;
         end if;

         if Is_Null (Subject_Type)
           or else not Subject_Type.P_Is_Discrete_Type
         then
            return;
         end if;

         for I in 1 .. Stmt.F_Alternatives.Children_Count loop
            declare
               Condition : constant Libadalang.Analysis.Expr :=
                 Stmt.F_Alternatives.Child (I).As_Elsif_Stmt_Part.F_Cond_Expr;
            begin
               if not Is_Static_Relation (Condition)
                 or else Condition.As_Relation_Op.F_Left.Kind not in
                           Libadalang.Common.Ada_Identifier
                           | Libadalang.Common.Ada_Dotted_Name
                 or else not Same_Name
                               (Condition.As_Relation_Op.F_Left, Subject)
               then
                  return;
               end if;
            end;
         end loop;

         Report_Finding
           (Unit, Item, Use_Case_Statement,
            "if statement testing one value can be a case statement");
      end;
   end Analyze_If;

   --  The record type whose component Dest assigns, when Dest is
   --  "Prefix.Component" of an untagged record type without
   --  discriminants; a null node otherwise.
   function Assigned_Record
     (Stmt : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Dest  : Libadalang.Analysis.Name;
      Decl  : Libadalang.Analysis.Basic_Decl;
      Owner : Node;
   begin
      if Is_Null (Stmt)
        or else Stmt.Kind /= Libadalang.Common.Ada_Assign_Stmt
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      Dest := Stmt.As_Assign_Stmt.F_Dest;
      if Dest.Kind /= Libadalang.Common.Ada_Dotted_Name
        or else Dest.As_Dotted_Name.F_Suffix.Kind /=
                  Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      Decl := Dest.As_Dotted_Name.F_Suffix.P_Referenced_Decl;
      if Is_Null (Decl)
        or else Decl.Kind /= Libadalang.Common.Ada_Component_Decl
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      Owner := Decl.P_Semantic_Parent;
      if Is_Null (Owner)
        or else Owner.Kind not in Libadalang.Common.Ada_Type_Decl
        or else not Is_Null (Owner.As_Type_Decl.F_Discriminants)
        or else Owner.As_Base_Type_Decl.P_Is_Tagged_Type
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;
      return Owner;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Assigned_Record;

   function Assigns_Component_Of
     (Stmt   : Libadalang.Analysis.Ada_Node'Class;
      Prefix : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (not Is_Null (Stmt)
       and then Stmt.Kind = Libadalang.Common.Ada_Assign_Stmt
       and then Stmt.As_Assign_Stmt.F_Dest.Kind =
                  Libadalang.Common.Ada_Dotted_Name
       and then Same_Name
                  (Stmt.As_Assign_Stmt.F_Dest.As_Dotted_Name.F_Prefix,
                   Prefix));

   procedure Analyze_Assignment
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Record_Type : constant Node := Assigned_Record (Item);
      Prefix      : Libadalang.Analysis.Name;
      Components  : Natural := 0;
      Assigned    : Natural := 0;
      Current     : Node := Item.As_Ada_Node;
      Seen        : array (1 .. 64) of Node;

      procedure Count (Candidate : Node) is
      begin
         if Candidate.Kind = Libadalang.Common.Ada_Defining_Name then
            Components := Components + 1;
         end if;
      end Count;
   begin
      if Is_Null (Record_Type) then
         return;
      end if;

      Prefix := Item.As_Assign_Stmt.F_Dest.As_Dotted_Name.F_Prefix;
      if Assigns_Component_Of (Item.Previous_Sibling, Prefix) then
         return;
      end if;

      For_Each (Record_Type.As_Type_Decl.F_Type_Def, Count'Access);
      if Components <= 1 then
         return;
      end if;

      --  Count the distinct components of this record assigned by the
      --  run of assignments to Prefix that starts here.
      while Assigns_Component_Of (Current, Prefix) loop
         if Assigned_Record (Current) = Record_Type then
            declare
               Suffix : constant Node :=
                 Current.As_Assign_Stmt.F_Dest.As_Dotted_Name.F_Suffix
                   .As_Ada_Node;
            begin
               if not (for some I in 1 .. Assigned =>
                         Same_Name (Seen (I), Suffix))
                 and then Assigned < Seen'Last
               then
                  Assigned := Assigned + 1;
                  Seen (Assigned) := Suffix;
               end if;
            end;
         end if;
         Current := Current.Next_Sibling;
      end loop;

      if Assigned = Components then
         Report_Finding
           (Unit, Item, Use_Record_Aggregate,
            "component assignments can be one aggregate assignment");
      end if;
   end Analyze_Assignment;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      if Kind = Libadalang.Common.Ada_While_Loop_Stmt then
         Guarded
           (Unit, Node, On (Use_Simple_Loop) or else On (Use_For_Loop),
            Analyze_While_Loop'Access);
      elsif Kind = Libadalang.Common.Ada_Loop_Stmt then
         Guarded (Unit, Node, On (Use_While_Loop), Analyze_Plain_Loop'Access);
      elsif Kind = Libadalang.Common.Ada_For_Loop_Stmt then
         Guarded
           (Unit, Node, On (Use_Array_Slice) or else On (Use_For_Of_Loop),
            Analyze_For_Loop'Access);
      elsif Kind = Libadalang.Common.Ada_Attribute_Ref then
         Guarded (Unit, Node, On (Use_Range), Analyze_Range'Access);
      elsif Kind = Libadalang.Common.Ada_Bin_Op then
         Guarded (Unit, Node, On (Use_Range), Analyze_Range'Access);
         Guarded (Unit, Node, On (Use_Membership), Analyze_Condition'Access);
      elsif Kind = Libadalang.Common.Ada_If_Stmt then
         Guarded
           (Unit, Node,
            On (Use_If_Expression) or else On (Use_Case_Statement),
            Analyze_If'Access);
      elsif Kind = Libadalang.Common.Ada_Assign_Stmt then
         Guarded
           (Unit, Node, On (Use_Record_Aggregate), Analyze_Assignment'Access);
      end if;
   end Analyze_Node;

end Adalang_Analyzer.Checks.Suggestions;
