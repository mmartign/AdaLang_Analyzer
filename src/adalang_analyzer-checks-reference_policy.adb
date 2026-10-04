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

with Adalang_Analyzer.Ada_Text;   use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks.Reference_Policy is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Defining_Name;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   subtype Node is Libadalang.Analysis.Ada_Node;

   function Is_Null (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
     renames Libadalang.Analysis.Is_Null;

   function Is_Simple_Name (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Base_Id
         | Libadalang.Common.Ada_Dotted_Name);

   function Same_Name
     (Left, Right : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (not Is_Null (Left) and then not Is_Null (Right)
       and then Is_Simple_Name (Left.Kind)
       and then Is_Simple_Name (Right.Kind)
       and then Canonical_Text (Left) = Canonical_Text (Right));

   function Definition_Of
     (Name : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Defining_Name
   is
   begin
      if Is_Null (Name) or else Name.Kind not in Libadalang.Common.Ada_Name
      then
         return Libadalang.Analysis.No_Defining_Name;
      end if;
      return Name.As_Name.P_Referenced_Defining_Name;
   exception
      when others =>
         return Libadalang.Analysis.No_Defining_Name;
   end Definition_Of;

   --  The object Name ultimately denotes, looking through renamings.
   function Ultimate_Alias
     (Name : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Decl : Node := Referenced (Name);
   begin
      for Step in 1 .. 16 loop
         exit when Is_Null (Decl)
           or else Decl.Kind /= Libadalang.Common.Ada_Object_Decl
           or else Is_Null (Decl.As_Object_Decl.F_Renaming_Clause);
         Decl := Referenced
           (Decl.As_Object_Decl.F_Renaming_Clause.F_Renamed_Object);
      end loop;
      return Decl;
   end Ultimate_Alias;

   function Enclosing
     (Item  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Node
   is
      Current : Node := Item.Parent;
   begin
      while not Is_Null (Current) and then not Match (Current.Kind) loop
         Current := Current.Parent;
      end loop;
      return Current;
   end Enclosing;

   function Is_Body (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Body_Node);

   function Is_Declare_Block (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Decl_Block);

   function Is_Loop (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Base_Loop_Stmt);

   function Is_Handler (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Exception_Handler);

   function Is_Protected_Body (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Protected_Body);

   --------------------
   --  Conditions    --
   --------------------

   function Is_Logic_Operator (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Op_And
         | Libadalang.Common.Ada_Op_And_Then
         | Libadalang.Common.Ada_Op_Or
         | Libadalang.Common.Ada_Op_Or_Else
         | Libadalang.Common.Ada_Op_Xor);

   procedure Analyze_Repeated_Operand
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Operation : constant Libadalang.Analysis.Bin_Op := Item.As_Bin_Op;
      Kind      : constant Node_Kind := Operation.F_Op.Kind;
      Operands  : array (1 .. 128) of Node;
      Total     : Natural := 0;
      Current   : Libadalang.Analysis.Bin_Op := Operation;
   begin
      if not Is_Logic_Operator (Kind)
        or else (Item.Parent.Kind in Libadalang.Common.Ada_Bin_Op
                   | Libadalang.Common.Ada_Relation_Op
                 and then Item.Parent.As_Bin_Op.F_Op.Kind = Kind)
      then
         return;
      end if;

      --  The operands of the whole chain "A op B op C ...".
      loop
         exit when Total + 2 > Operands'Last;
         Operands (Total + 1) := Current.F_Left.As_Ada_Node;
         Operands (Total + 2) := Current.F_Right.As_Ada_Node;
         Total := Total + 2;
         exit when Current.F_Left.Kind not in Libadalang.Common.Ada_Bin_Op
                     | Libadalang.Common.Ada_Relation_Op
           or else Current.F_Left.As_Bin_Op.F_Op.Kind /= Kind;
         Current := Current.F_Left.As_Bin_Op;
      end loop;

      for I in 1 .. Total loop
         for J in 1 .. Total loop
            if I /= J
              and then Canonical_Text (Operands (I)) =
                         Canonical_Text (Operands (J))
            then
               Report_Finding
                 (Unit, Operands (I), Same_Logic,
                  "the same operand appears twice in this condition");
               return;
            end if;
         end loop;
      end loop;
   end Analyze_Repeated_Operand;

   function Is_Literal (Item : Libadalang.Analysis.Expr'Class) return Boolean
   is
      Decl : Node;
   begin
      if Item.Kind in Libadalang.Common.Ada_Char_Literal
           | Libadalang.Common.Ada_Num_Literal
           | Libadalang.Common.Ada_String_Literal
      then
         return True;
      elsif Item.Kind not in Libadalang.Common.Ada_Name then
         return False;
      end if;

      Decl := Referenced (Item);
      return not Is_Null (Decl)
        and then Decl.Kind = Libadalang.Common.Ada_Enum_Literal_Decl;
   end Is_Literal;

   --  True when the two operands of Item, joined by "and" (Conjunction) or
   --  by "or", compare the same name with literals by "=" (respectively
   --  "/="): a test that can never (respectively always) hold.
   function Is_Suspicious
     (Item : Libadalang.Analysis.Bin_Op; Conjunction : Boolean) return Boolean
   is
      function Is_Logic (Kind : Node_Kind) return Boolean
      is (if Conjunction
          then Kind in Libadalang.Common.Ada_Op_And
                 | Libadalang.Common.Ada_Op_And_Then
          else Kind in Libadalang.Common.Ada_Op_Or
                 | Libadalang.Common.Ada_Op_Or_Else);

      function Is_Comparison (Kind : Node_Kind) return Boolean
      is (if Conjunction then Kind = Libadalang.Common.Ada_Op_Eq
          else Kind = Libadalang.Common.Ada_Op_Neq);

      Names : array (Boolean, 1 .. 64) of Node;
      Count : array (Boolean) of Natural := (others => 0);

      procedure Collect
        (Operand : Libadalang.Analysis.Expr'Class; Side : Boolean)
      is
         Operation : Libadalang.Analysis.Bin_Op;
      begin
         if Operand.Kind = Libadalang.Common.Ada_Paren_Expr then
            Collect (Operand.As_Paren_Expr.F_Expr, Side);
            return;
         elsif Operand.Kind not in Libadalang.Common.Ada_Bin_Op
                 | Libadalang.Common.Ada_Relation_Op
         then
            return;
         end if;

         Operation := Operand.As_Bin_Op;
         if Is_Comparison (Operation.F_Op.Kind)
           and then ((Operation.F_Left.Kind in Libadalang.Common.Ada_Name
                      and then Is_Literal (Operation.F_Right))
                     or else (Is_Literal (Operation.F_Left)
                              and then Operation.F_Right.Kind in
                                         Libadalang.Common.Ada_Name))
         then
            if Count (Side) < 64 then
               Count (Side) := Count (Side) + 1;
               Names (Side, Count (Side)) :=
                 (if Operation.F_Left.Kind in Libadalang.Common.Ada_Name
                  then Operation.F_Left.As_Ada_Node
                  else Operation.F_Right.As_Ada_Node);
            end if;
         elsif Is_Logic (Operation.F_Op.Kind) then
            Collect (Operation.F_Left, Side);
            Collect (Operation.F_Right, Side);
         end if;
      end Collect;
   begin
      if not Is_Logic (Item.F_Op.Kind) then
         return False;
      end if;

      Collect (Item.F_Left, False);
      Collect (Item.F_Right, True);
      for I in 1 .. Count (False) loop
         for J in 1 .. Count (True) loop
            if Same_Name (Names (False, I), Names (True, J)) then
               return True;
            end if;
         end loop;
      end loop;
      return False;
   end Is_Suspicious;

   --------------------
   --  Exceptions    --
   --------------------

   --  The statements and declarations of a subprogram body, task body or
   --  declare block, or null nodes for any other construct.
   procedure Get_Frame
     (Scope : Node;
      Stmts : out Libadalang.Analysis.Handled_Stmts;
      Decls : out Node)
   is
   begin
      Stmts := Libadalang.Analysis.No_Handled_Stmts;
      Decls := Libadalang.Analysis.No_Ada_Node;
      if Is_Null (Scope) then
         return;
      end if;

      case Scope.Kind is
         when Libadalang.Common.Ada_Subp_Body =>
            Stmts := Scope.As_Subp_Body.F_Stmts;
            Decls := Scope.As_Subp_Body.F_Decls.As_Ada_Node;
         when Libadalang.Common.Ada_Task_Body =>
            Stmts := Scope.As_Task_Body.F_Stmts;
            Decls := Scope.As_Task_Body.F_Decls.As_Ada_Node;
         when Libadalang.Common.Ada_Decl_Block =>
            Stmts := Scope.As_Decl_Block.F_Stmts;
            Decls := Scope.As_Decl_Block.F_Decls.As_Ada_Node;
         when others =>
            null;
      end case;
   end Get_Frame;

   --  A local exception that its own scope does not handle.
   procedure Analyze_Local_Exception
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl    : constant Node := Item.Parent.Parent.Parent;
      Stmts   : Libadalang.Analysis.Handled_Stmts;
      Decls   : Node;
      Handled : Boolean := False;

      procedure Visit (Candidate : Node) is
      begin
         if Candidate.Kind = Libadalang.Common.Ada_Others_Designator
           or else (Candidate.Kind in Libadalang.Common.Ada_Identifier
                      | Libadalang.Common.Ada_Dotted_Name
                    and then Canonical_Exception (Candidate) = Decl)
         then
            Handled := True;
         end if;
      end Visit;
   begin
      Get_Frame (Decl.P_Semantic_Parent, Stmts, Decls);
      if Is_Null (Decls) then
         return;
      end if;

      if not Is_Null (Stmts) then
         for I in 1 .. Stmts.F_Exceptions.Children_Count loop
            if Stmts.F_Exceptions.Child (I).Kind =
                 Libadalang.Common.Ada_Exception_Handler
            then
               For_Each_Below
                 (Stmts.F_Exceptions.Child (I).As_Exception_Handler
                    .F_Handled_Exceptions,
                  Visit'Access);
            end if;
         end loop;
      end if;

      if not Handled then
         Report_Finding
           (Unit, Item, Non_Visible_Exception,
            "local exception is not handled in the scope that declares it");
      end if;
   end Analyze_Local_Exception;

   --  A handler that raises, or re-raises, an exception local to its scope.
   procedure Analyze_Propagating_Raise
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Handler : constant Node := Enclosing (Item, Is_Handler'Access);
      Scope   : Node;
      Stmts   : Libadalang.Analysis.Handled_Stmts;
      Decls   : Node;
      Name    : constant Libadalang.Analysis.Name :=
        Item.As_Raise_Stmt.F_Exception_Name;
      Leaks   : Boolean := False;
   begin
      if Is_Null (Handler) then
         return;
      end if;

      Scope := Handler.P_Semantic_Parent;
      Get_Frame (Scope, Stmts, Decls);
      if Is_Null (Decls) then
         return;
      end if;

      if not Is_Null (Name) then
         declare
            Raised : constant Node := Referenced (Name);
         begin
            Leaks := not Is_Null (Raised)
              and then not Is_Null (Raised.Parent)
              and then Raised.Parent.Parent = Decls;
         end;
      else
         declare
            Choices : constant Libadalang.Analysis.Alternatives_List :=
              Handler.As_Exception_Handler.F_Handled_Exceptions;
         begin
            for I in 1 .. Choices.Children_Count loop
               if Choices.Child (I).Kind = Libadalang.Common.Ada_Identifier
               then
                  declare
                     Caught : constant Node := Referenced (Choices.Child (I));
                  begin
                     if not Is_Null (Caught)
                       and then Caught.P_Semantic_Parent = Scope
                     then
                        Leaks := True;
                     end if;
                  end;
               end if;
            end loop;
         end;
      end if;

      if Leaks then
         Report_Finding
           (Unit, Item, Non_Visible_Exception,
            "handler propagates a local exception outside its visibility");
      end if;
   end Analyze_Propagating_Raise;

   -----------------------------
   --  Objects and scopes     --
   -----------------------------

   procedure Analyze_Protected_Assignment
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Owner   : constant Node := Enclosing (Item, Is_Protected_Body'Access);
      Spec    : Node;
      Target  : Node;
      Current : Node;
   begin
      if Is_Null (Owner) then
         return;
      end if;

      Spec := Owner.As_Body_Node.P_Decl_Part.As_Ada_Node;
      Target := Ultimate_Alias (Item.As_Assign_Stmt.F_Dest);
      Current := (if Is_Null (Target) then Target else Target.Parent);
      while not Is_Null (Current) loop
         if Current = Owner
           or else (not Is_Null (Spec) and then Current = Spec)
         then
            return;
         end if;
         Current := Current.Parent;
      end loop;

      Report_Finding
        (Unit, Item, Outbound_Protected_Assignment,
         "protected body assigns to an object outside the protected unit");
   end Analyze_Protected_Assignment;

   procedure Analyze_Outside_References
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Own_Spec : constant Node :=
        Item.As_Basic_Decl.P_Subp_Spec_Or_Null.As_Ada_Node;

      procedure Visit (Candidate : Node) is
         Target : Node;
         Home   : Node;
      begin
         if Candidate.Kind /= Libadalang.Common.Ada_Identifier then
            return;
         end if;

         Target := Ultimate_Alias (Candidate);
         if Is_Null (Target) then
            return;
         elsif Target.Kind in Libadalang.Common.Ada_Object_Decl_Range then
            --  The common case is an object of this very body: rule it
            --  out before the costlier scope query.
            Home := Enclosing (Target, Is_Body'Access);
            if not Is_Null (Home)
              and then Home.Kind in Libadalang.Common.Ada_Base_Subp_Body
              and then Home /= Item.As_Ada_Node
            then
               if Has_Local_Scope (Target) then
                  Report_Finding
                    (Unit, Candidate, Outside_Reference_From_Subprogram,
                     "subprogram refers to a local object of an enclosing "
                     & "subprogram");
               end if;
            end if;
         elsif Target.Kind = Libadalang.Common.Ada_Param_Spec
           and then not (Candidate.Parent.Kind =
                           Libadalang.Common.Ada_Param_Assoc
                         and then Candidate.Parent.As_Param_Assoc.F_Designator
                                    .As_Ada_Node = Candidate)
           and then Target.Parent.Parent.Parent /= Own_Spec
         then
            Report_Finding
              (Unit, Candidate, Outside_Reference_From_Subprogram,
               "subprogram refers to a parameter of an enclosing "
               & "subprogram");
         end if;
      exception
         when Exc : others =>
            Note_Skipped_Check (Candidate, Exc);
      end Visit;
   begin
      if In_Generic_Template (Item) then
         return;
      end if;
      For_Each_Below (Item, Visit'Access, Skip_Nested_Bodies => True);
   end Analyze_Outside_References;

   procedure Analyze_Variable_Scope
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl  : constant Node := Item.Parent.Parent;
      Subp  : Node;
      Block : Node := Libadalang.Analysis.No_Ada_Node;
      Uses  : Natural := 0;
      Apart : Boolean := False;

      procedure Visit (Candidate : Node) is
         Home : Node;
      begin
         if Candidate.Kind /= Libadalang.Common.Ada_Identifier
           or else Candidate = Item.As_Defining_Name.F_Name.As_Ada_Node
           or else not Same_Name (Candidate, Item.As_Defining_Name.F_Name)
           or else Definition_Of (Candidate) /= Item.As_Defining_Name
         then
            return;
         end if;

         Home := Enclosing (Candidate, Is_Declare_Block'Access);
         Uses := Uses + 1;
         if Uses = 1 then
            Block := Home;
         elsif Home /= Block then
            Apart := True;
         end if;
      end Visit;
   begin
      if Decl.Kind /= Libadalang.Common.Ada_Object_Decl
        or else not Is_Null (Decl.As_Object_Decl.F_Default_Expr)
        or else not Is_Null (Decl.As_Object_Decl.F_Renaming_Clause)
        or else Is_Null (Decl.Parent)
        or else Is_Null (Decl.Parent.Parent)
        or else Decl.Parent.Parent.Kind /=
                  Libadalang.Common.Ada_Declarative_Part
        or else Decl.Parent.Parent.Parent.Kind /=
                  Libadalang.Common.Ada_Subp_Body
      then
         return;
      end if;

      Subp := Decl.Parent.Parent.Parent;
      For_Each_Below (Subp, Visit'Access);

      if Uses > 0
        and then not Apart
        and then not Is_Null (Block)
        and then Is_Null (Enclosing (Block, Is_Loop'Access))
        and then Enclosing (Block, Is_Body'Access) = Subp
      then
         Report_Finding
           (Unit, Item, Variable_Scoping,
            "variable is used only in the block at line "
            & To_Decimal (Natural (Block.Sloc_Range.Start_Line))
            & " and can be declared there");
      end if;
   end Analyze_Variable_Scope;

   --  An out or in out actual that a handler of an enclosing block reads:
   --  the call may have been abandoned before assigning it.
   procedure Analyze_Out_Actual
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Assoc   : constant Libadalang.Analysis.Param_Assoc := Item.As_Param_Assoc;
      Target  : Libadalang.Analysis.Defining_Name;
      Renamed : Libadalang.Analysis.Defining_Name :=
        Libadalang.Analysis.No_Defining_Name;
      Current : Node := Item.Parent;
      Read    : Boolean := False;

      procedure Visit (Candidate : Node) is
         Found : Libadalang.Analysis.Defining_Name;
      begin
         if Read or else Candidate.Kind /= Libadalang.Common.Ada_Identifier
         then
            return;
         end if;

         Found := Definition_Of (Candidate);
         if not Is_Null (Found)
           and then (Found = Target
                     or else (not Is_Null (Renamed)
                              and then Found = Renamed))
           and then not Candidate.As_Name.P_Is_Write_Reference
         then
            Read := True;
         end if;
      exception
         when Exc : others =>
            Note_Skipped_Check (Candidate, Exc);
      end Visit;
   begin
      if Assoc.F_R_Expr.Kind not in Libadalang.Common.Ada_Identifier
           | Libadalang.Common.Ada_Dotted_Name
        or else Item.Parent.Kind /= Libadalang.Common.Ada_Assoc_List
        or else Item.Parent.Parent.Kind /= Libadalang.Common.Ada_Call_Expr
        or else not Item.Parent.Parent.As_Call_Expr.P_Is_Call
        or else Has_Ancestor (Item, Is_Handler'Access)
      then
         return;
      end if;

      declare
         Formals : constant Libadalang.Analysis.Defining_Name_Array :=
           Assoc.P_Get_Params;
         Formal  : Libadalang.Analysis.Basic_Decl;
      begin
         if Formals'Length = 0 then
            return;
         end if;

         Formal := Formals (Formals'First).P_Basic_Decl;
         if Formal.Kind /= Libadalang.Common.Ada_Param_Spec
           or else Formal.As_Param_Spec.F_Mode.Kind not in
                     Libadalang.Common.Ada_Mode_Out
                     | Libadalang.Common.Ada_Mode_In_Out
         then
            return;
         end if;
      end;

      Target := Definition_Of (Assoc.F_R_Expr);
      if Is_Null (Target) then
         return;
      end if;

      if Target.P_Basic_Decl.Kind = Libadalang.Common.Ada_Object_Decl
        and then not Is_Null
                       (Target.P_Basic_Decl.As_Object_Decl.F_Renaming_Clause)
      then
         Renamed := Definition_Of
           (Target.P_Basic_Decl.As_Object_Decl.F_Renaming_Clause
              .F_Renamed_Object);
      end if;

      while not Is_Null (Current) and then not Read loop
         if Current.Kind = Libadalang.Common.Ada_Handled_Stmts then
            For_Each_Below
              (Current.As_Handled_Stmts.F_Exceptions, Visit'Access);
         end if;
         Current := Current.Parent;
      end loop;

      if Read then
         Report_Finding
           (Unit, Item, Out_Parameter_Read_In_Exception_Handler,
            "out actual " & Node_Text (Assoc.F_R_Expr)
            & " is read in an exception handler of an enclosing block");
      end if;
   end Analyze_Out_Actual;

   --------------------------------
   --  Predicates and profiles   --
   --------------------------------

   function Has_Predicate
     (Decl : Node; Depth : Natural := 0) return Boolean
   is
   begin
      if Is_Null (Decl) or else Depth > 32 then
         return False;
      elsif Decl.Kind = Libadalang.Common.Ada_Subtype_Decl then
         return Has_Aspect (Decl.As_Basic_Decl, "Predicate")
           or else Has_Aspect (Decl.As_Basic_Decl, "Static_Predicate")
           or else Has_Aspect (Decl.As_Basic_Decl, "Dynamic_Predicate")
           or else Has_Predicate
                     (Referenced (Decl.As_Subtype_Decl.F_Subtype.F_Name),
                      Depth + 1);
      elsif Decl.Kind in Libadalang.Common.Ada_Type_Decl
        and then not Is_Null (Decl.As_Type_Decl.F_Type_Def)
        and then Decl.As_Type_Decl.F_Type_Def.Kind =
                   Libadalang.Common.Ada_Derived_Type_Def
      then
         return Has_Predicate
           (Referenced
              (Decl.As_Type_Decl.F_Type_Def.As_Derived_Type_Def
                 .F_Subtype_Indication.F_Name),
            Depth + 1);
      end if;
      return False;
   end Has_Predicate;

   procedure Analyze_Predicate_Test
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Tested : Boolean := False;

      procedure Visit (Candidate : Node) is
      begin
         if not Tested
           and then Candidate.Kind = Libadalang.Common.Ada_Identifier
           and then Has_Predicate (Referenced (Candidate))
         then
            Tested := True;
         end if;
      end Visit;
   begin
      if Item.Kind = Libadalang.Common.Ada_Membership_Expr then
         For_Each_Below
           (Item.As_Membership_Expr.F_Membership_Exprs, Visit'Access);
      elsif Canonical_Text (Item.As_Attribute_Ref.F_Attribute) = "valid" then
         Tested := Has_Predicate
           (Item.As_Attribute_Ref.F_Prefix.P_Expression_Type.As_Ada_Node);
      end if;

      if Tested then
         Report_Finding
           (Unit, Item, Predicate_Testing,
            "expression evaluates a subtype predicate");
      end if;
   end Analyze_Predicate_Test;

   --  True when the identifiers of the two type expressions differ.
   function Types_Differ
     (Left, Right : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      type Name_List is array (1 .. 32) of Node;
      Lefts, Rights : Name_List;
      Left_Count, Right_Count : Natural := 0;

      procedure Add_Left (Candidate : Node) is
      begin
         if Candidate.Kind = Libadalang.Common.Ada_Identifier
           and then Left_Count < Name_List'Last
         then
            Left_Count := Left_Count + 1;
            Lefts (Left_Count) := Candidate;
         end if;
      end Add_Left;

      procedure Add_Right (Candidate : Node) is
      begin
         if Candidate.Kind = Libadalang.Common.Ada_Identifier
           and then Right_Count < Name_List'Last
         then
            Right_Count := Right_Count + 1;
            Rights (Right_Count) := Candidate;
         end if;
      end Add_Right;
   begin
      if not Is_Null (Left) then
         Add_Left (Left.As_Ada_Node);
         For_Each_Below (Left, Add_Left'Access);
      end if;
      if not Is_Null (Right) then
         Add_Right (Right.As_Ada_Node);
         For_Each_Below (Right, Add_Right'Access);
      end if;

      if Left_Count /= Right_Count then
         return True;
      end if;

      for I in 1 .. Left_Count loop
         if not Same_Name (Lefts (I), Rights (I)) then
            return True;
         end if;
      end loop;
      return False;
   end Types_Differ;

   function Parameters_Differ
     (Left, Right : Libadalang.Analysis.Params) return Boolean
   is
      Left_Count  : constant Natural :=
        (if Is_Null (Left) then 0 else Left.F_Params.Children_Count);
      Right_Count : constant Natural :=
        (if Is_Null (Right) then 0 else Right.F_Params.Children_Count);
   begin
      if Left_Count /= Right_Count then
         return True;
      end if;

      for I in 1 .. Left_Count loop
         declare
            Mine   : constant Libadalang.Analysis.Param_Spec :=
              Left.F_Params.Child (I).As_Param_Spec;
            Theirs : constant Libadalang.Analysis.Param_Spec :=
              Right.F_Params.Child (I).As_Param_Spec;
         begin
            if (Mine.F_Mode.Kind = Libadalang.Common.Ada_Mode_Default) /=
                 (Theirs.F_Mode.Kind = Libadalang.Common.Ada_Mode_Default)
              or else Mine.F_Ids.Children_Count /=
                        Theirs.F_Ids.Children_Count
              or else Types_Differ (Mine.F_Type_Expr, Theirs.F_Type_Expr)
            then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Parameters_Differ;

   procedure Analyze_Profile
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl   : Node := Item.As_Body_Node.P_Decl_Part.As_Ada_Node;
      Differ : Boolean;
   begin
      if Is_Null (Decl) then
         return;
      end if;

      if Item.Kind = Libadalang.Common.Ada_Entry_Body then
         if Decl.Kind /= Libadalang.Common.Ada_Entry_Decl then
            return;
         end if;
         Differ := Parameters_Differ
           ((if Is_Null (Item.As_Entry_Body.F_Params)
             then Libadalang.Analysis.No_Params
             else Item.As_Entry_Body.F_Params.F_Params),
            Decl.As_Entry_Decl.F_Spec.F_Entry_Params);
      else
         if Decl.Kind = Libadalang.Common.Ada_Generic_Subp_Decl then
            Decl := Decl.As_Generic_Subp_Decl.F_Subp_Decl.As_Ada_Node;
         end if;

         declare
            Mine   : constant Libadalang.Analysis.Subp_Spec :=
              (if Item.Kind = Libadalang.Common.Ada_Subp_Body_Stub
               then Item.As_Subp_Body_Stub.F_Subp_Spec
               else Item.As_Base_Subp_Body.F_Subp_Spec);
            Theirs : Libadalang.Analysis.Subp_Spec;
         begin
            if Decl.Kind = Libadalang.Common.Ada_Generic_Subp_Internal then
               Theirs := Decl.As_Generic_Subp_Internal.F_Subp_Spec;
            elsif Decl.Kind in Libadalang.Common.Ada_Classic_Subp_Decl then
               Theirs := Decl.As_Classic_Subp_Decl.F_Subp_Spec;
            else
               return;
            end if;

            Differ := Types_Differ (Mine.F_Subp_Returns, Theirs.F_Subp_Returns)
              or else Parameters_Differ
                        (Mine.F_Subp_Params, Theirs.F_Subp_Params);
         end;
      end if;

      if Differ then
         Report_Finding
           (Unit, Item.As_Basic_Decl.P_Defining_Name, Profile_Discrepancy,
            "parameter profile is written differently from the declaration "
            & "at line " & To_Decimal (Natural (Decl.Sloc_Range.Start_Line)));
      end if;
   end Analyze_Profile;

   --  Reports a call or instantiation that passes, in two or more
   --  actuals, calls to the same function listed in the functions
   --  parameter: their order of evaluation is not defined.
   procedure Analyze_Side_Effects
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Functions : constant String :=
        Text_Parameter (Side_Effect_Parameter, "functions");
      Names     : array (1 .. 64) of Langkit_Support.Text.Unbounded_Text_Type;
      Total     : Natural := 0;
      Repeated  : Boolean := False;

      procedure Visit (Candidate : Node) is
         Decl : Node;
      begin
         if Candidate.Kind not in Libadalang.Common.Ada_Base_Id then
            return;
         end if;

         Decl := Referenced (Candidate);
         for Step in 1 .. 8 loop
            exit when Is_Null (Decl)
              or else Decl.Kind /= Libadalang.Common.Ada_Subp_Renaming_Decl;
            Decl := Referenced
              (Decl.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object);
         end loop;

         if Is_Null (Decl)
           or else Decl.Kind not in Libadalang.Common.Ada_Basic_Subp_Decl
         then
            return;
         end if;

         declare
            Full_Name : constant Langkit_Support.Text.Text_Type :=
              Decl.As_Basic_Decl.P_Canonical_Fully_Qualified_Name;
            Unbounded : constant Langkit_Support.Text.Unbounded_Text_Type :=
              Langkit_Support.Text.To_Unbounded_Text (Full_Name);
            use type Langkit_Support.Text.Unbounded_Text_Type;
         begin
            if not Is_Listed
                     (Langkit_Support.Text.To_UTF8 (Full_Name), Functions)
            then
               return;
            end if;

            for I in 1 .. Total loop
               if Names (I) = Unbounded then
                  Repeated := True;
               end if;
            end loop;

            if Total < Names'Last then
               Total := Total + 1;
               Names (Total) := Unbounded;
            end if;
         end;
      end Visit;

      procedure Scan (Actual : Node) is
      begin
         if not Is_Null (Actual) then
            Visit (Actual);
            For_Each_Below (Actual, Visit'Access);
         end if;
      end Scan;
   begin
      if Functions = "" then
         return;
      end if;

      if Item.Kind in Libadalang.Common.Ada_Generic_Instantiation then
         for Pair of Item.As_Generic_Instantiation.P_Inst_Params loop
            Scan (Libadalang.Analysis.Actual (Pair).As_Ada_Node);
         end loop;
      elsif not Is_Null (Item.Parent)
        and then Item.Parent.Kind in Libadalang.Common.Ada_Name
        and then Item.Parent.As_Name.P_Is_Call
      then
         for Pair of Item.Parent.As_Name.P_Call_Params loop
            Scan (Libadalang.Analysis.Actual (Pair).As_Ada_Node);
         end loop;
      end if;

      if Repeated then
         Report_Finding
           (Unit, Item, Side_Effect_Parameter,
            "actuals call the same function with side effects more than "
            & "once");
      end if;
   end Analyze_Side_Effects;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Bin_Op
           | Libadalang.Common.Ada_Relation_Op
      then
         Guarded (Unit, Node, On (Same_Logic), Analyze_Repeated_Operand'Access);

         if On (Suspicious_Equality) then
            begin
               if Is_Suspicious (Node.As_Bin_Op, Conjunction => True)
                 or else Is_Suspicious (Node.As_Bin_Op, Conjunction => False)
               then
                  Report_Finding
                    (Unit, Node, Suspicious_Equality,
                     "the same name is compared with two literals in a way "
                     & "that is always or never true");
               end if;
            exception
               when Exc : others =>
                  Note_Skipped_Check (Node, Exc);
            end;
         end if;
      elsif Kind = Libadalang.Common.Ada_Raise_Stmt then
         Guarded
           (Unit, Node, On (Non_Visible_Exception),
            Analyze_Propagating_Raise'Access);
      elsif Kind = Libadalang.Common.Ada_Assign_Stmt then
         Guarded
           (Unit, Node, On (Outbound_Protected_Assignment),
            Analyze_Protected_Assignment'Access);
      elsif Kind = Libadalang.Common.Ada_Param_Assoc then
         Guarded
           (Unit, Node, On (Out_Parameter_Read_In_Exception_Handler),
            Analyze_Out_Actual'Access);
      elsif Kind = Libadalang.Common.Ada_Membership_Expr
        or else Kind = Libadalang.Common.Ada_Attribute_Ref
      then
         Guarded
           (Unit, Node, On (Predicate_Testing), Analyze_Predicate_Test'Access);
      elsif Kind = Libadalang.Common.Ada_Assoc_List
        or else Kind in Libadalang.Common.Ada_Generic_Instantiation
      then
         Guarded
           (Unit, Node, On (Side_Effect_Parameter),
            Analyze_Side_Effects'Access);
      elsif Kind = Libadalang.Common.Ada_Identifier
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind = Libadalang.Common.Ada_Defining_Name
        and then not Libadalang.Analysis.Is_Null (Node.Parent.Parent)
        and then Node.Parent.Parent.Kind =
                   Libadalang.Common.Ada_Defining_Name_List
        and then Node.Parent.Parent.Parent.Kind =
                   Libadalang.Common.Ada_Exception_Decl
        and then Libadalang.Analysis.Is_Null
                   (Node.Parent.Parent.Parent.As_Exception_Decl.F_Renames)
      then
         Guarded
           (Unit, Node, On (Non_Visible_Exception),
            Analyze_Local_Exception'Access);
      elsif Kind = Libadalang.Common.Ada_Defining_Name
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind = Libadalang.Common.Ada_Defining_Name_List
        and then not Libadalang.Analysis.Is_Null (Node.Parent.Parent)
      then
         Guarded
           (Unit, Node, On (Variable_Scoping), Analyze_Variable_Scope'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Base_Subp_Body then
         Guarded
           (Unit, Node, On (Outside_Reference_From_Subprogram),
            Analyze_Outside_References'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Base_Subp_Body
           | Libadalang.Common.Ada_Subp_Body_Stub
           | Libadalang.Common.Ada_Entry_Body
      then
         Guarded (Unit, Node, On (Profile_Discrepancy), Analyze_Profile'Access);
      end if;
   end Analyze_Node;

end Adalang_Analyzer.Checks.Reference_Policy;
