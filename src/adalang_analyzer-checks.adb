--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Exceptions;
with Ada.Strings.Fixed;

with Libadalang.Common;
with Langkit_Support.Text;

with Adalang_Analyzer.Ada_Text;             use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Control_Flow;
with Adalang_Analyzer.Checks.Data_Flow;
with Adalang_Analyzer.Checks.Declarations;
with Adalang_Analyzer.Checks.Expressions;
with Adalang_Analyzer.Config;               use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Domain;          use Adalang_Analyzer.Flow_Domain;
with Adalang_Analyzer.Flow_Eval;            use Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Report;               use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;                use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils;           use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   --  True when Node's nearest enclosing statement/declaration is itself a
   --  named-number or constant object declaration, i.e. Node is the value
   --  being given a name rather than a "magic number" used inline.
   function Is_In_Named_Constant_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         case Ancestor.Kind is
            when Libadalang.Common.Ada_Number_Decl =>
               return True;

            when Libadalang.Common.Ada_Object_Decl =>
               declare
                  Declaration : constant Libadalang.Analysis.Object_Decl :=
                    Ancestor.As_Object_Decl;
               begin
                  return Declaration.F_Has_Constant
                    or else Ada.Strings.Fixed.Index
                      (Ada.Characters.Handling.To_Lower
                         (Node_Text (Declaration)),
                       "constant") /= 0;
               end;

            when others =>
               if Ancestor.Kind in Libadalang.Common.Ada_Stmt
                 or else Ancestor.Kind in Libadalang.Common.Ada_Basic_Decl
               then
                  return False;
               end if;
               Ancestor := Ancestor.Parent;
         end case;
      end loop;

      return False;
   exception
      when others =>
         return False;
   end Is_In_Named_Constant_Declaration;

   --  True when a numeric literal is exempt from Magic_Number: 0, 1, and
   --  -1 are conventionally self-explanatory, and a literal that is
   --  itself the definition of a named constant is, by definition, named.
   function Is_Allowed_Magic_Number
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      return Is_Static_Zero (Node)
        or else Is_Static_One (Node)
        or else Is_In_Named_Constant_Declaration (Node);
   end Is_Allowed_Magic_Number;

   --  Reports Constant_Condition when Cond statically evaluates to a fixed
   --  boolean. Shared by if/elsif/while/exit-when condition sites.
   procedure Report_Constant_Condition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Cond : Libadalang.Analysis.Ada_Node'Class)
   is
      Value : constant Abstract_Bool := Boolean_Value (Cond);
   begin
      if Rule_States (Constant_Condition) = Enabled
        and then Value /= Bool_Unknown
      then
         Report_Rule_Violation
           (Unit, Cond, Constant_Condition,
            "condition is always " & Bool_Name (Value));
      end if;
   end Report_Constant_Condition;

   --  Reports Non_Short_Circuit_Condition for every plain "and"/"or"
   --  operator anywhere within Cond's subtree. Shared by if/elsif/while/
   --  exit-when condition sites, alongside Report_Constant_Condition.
   procedure Report_Non_Short_Circuit_Operators
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Cond : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Rule_States (Non_Short_Circuit_Condition) /= Enabled
        or else Libadalang.Analysis.Is_Null (Cond)
      then
         return;
      end if;

      if Cond.Kind in Libadalang.Common.Ada_Bin_Op_Range then
         case Cond.As_Bin_Op.F_Op is
            when Libadalang.Common.Ada_Op_And =>
               Report_Rule_Violation
                 (Unit, Cond, Non_Short_Circuit_Condition,
                  "use 'and then' instead of 'and' in a condition");
            when Libadalang.Common.Ada_Op_Or =>
               Report_Rule_Violation
                 (Unit, Cond, Non_Short_Circuit_Condition,
                  "use 'or else' instead of 'or' in a condition");
            when others =>
               null;  --  adalang-analyzer: ignore Null_Statement
         end case;
      end if;

      for I in 1 .. Cond.Children_Count loop
         Report_Non_Short_Circuit_Operators (Unit, Cond.Child (I));
      end loop;
   end Report_Non_Short_Circuit_Operators;

   --  Return the boolean expression checked by an assertion-like pragma.
   --  Check has a leading check-kind argument; the others carry their
   --  condition first.
   function Assertion_Expression
     (Pragma_Node : Libadalang.Analysis.Pragma_Node)
      return Libadalang.Analysis.Expr
   is
      Name  : constant String := Canonical_Text (Pragma_Node.F_Id);
      Index : Positive := 1;
   begin
      if Name = "check" then
         Index := 2;
      elsif Name /= "assert"
        and then Name /= "assert_and_cut"
        and then Name /= "loop_invariant"
      then
         return Libadalang.Analysis.No_Expr;
      end if;

      if Pragma_Node.F_Args.Children_Count < Index then
         return Libadalang.Analysis.No_Expr;
      end if;

      return Pragma_Node.F_Args.Child (Index).As_Pragma_Argument_Assoc.P_Assoc_Expr;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Assertion_Expression;

   --  Dispatches Node to the check(s) keyed on its specific syntactic
   --  kind (statement lists, operators, assignments, if/case/loop
   --  constructs, exception handlers, and so on). Called once per node
   --  from Evaluate_Node, alongside the always-run structural checks
   --  handled directly there.
   procedure Analyze_Bug_Finding_Node  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      case Node.Kind is
         when Libadalang.Common.Ada_Stmt_List =>
            Control_Flow.Analyze_Statement_List (Unit, Node);

         when Libadalang.Common.Ada_Bin_Op_Range =>
            Expressions.Analyze_Binary_Expression (Unit, Node.As_Bin_Op);

         when Libadalang.Common.Ada_Un_Op =>
            Expressions.Analyze_Unary_Expression (Unit, Node.As_Un_Op);

         when Libadalang.Common.Ada_Assign_Stmt =>
            Control_Flow.Analyze_Assignment (Unit, Node.As_Assign_Stmt);

         when Libadalang.Common.Ada_Call_Stmt =>
            Control_Flow.Analyze_Call_Statement (Unit, Node.As_Call_Stmt);

         when Libadalang.Common.Ada_Object_Decl =>
            Declarations.Analyze_Object_Declaration
              (Unit, Node.As_Object_Decl);

         when Libadalang.Common.Ada_Subp_Body =>
            Declarations.Analyze_Subprogram (Unit, Node.As_Subp_Body);

         when Libadalang.Common.Ada_Case_Stmt =>
            Control_Flow.Analyze_Case_Statement (Unit, Node.As_Case_Stmt);

         when Libadalang.Common.Ada_Call_Expr =>
            if Rule_States (No_Recursion) = Enabled then
               declare
                  Subprogram : constant Libadalang.Analysis.Subp_Body :=
                    Data_Flow.Enclosing_Subprogram (Node);
               begin
                  if not Libadalang.Analysis.Is_Null (Subprogram)
                    and then Data_Flow.Is_Direct_Recursive_Call
                      (Node.As_Call_Expr, Subprogram)
                  then
                     Report_Rule_Violation
                       (Unit, Node, No_Recursion,
                        "subprogram calls itself");
                  end if;
               end;
            end if;

         when Libadalang.Common.Ada_If_Stmt =>
            Report_Constant_Condition
              (Unit, Node.As_If_Stmt.F_Cond_Expr);
            Report_Non_Short_Circuit_Operators
              (Unit, Node.As_If_Stmt.F_Cond_Expr);
            Control_Flow.Analyze_If_Statement (Unit, Node.As_If_Stmt);

         when Libadalang.Common.Ada_Elsif_Stmt_Part =>
            Report_Constant_Condition
              (Unit, Node.As_Elsif_Stmt_Part.F_Cond_Expr);
            Report_Non_Short_Circuit_Operators
              (Unit, Node.As_Elsif_Stmt_Part.F_Cond_Expr);

         when Libadalang.Common.Ada_If_Expr =>
            Report_Constant_Condition
              (Unit, Node.As_If_Expr.F_Cond_Expr);
            Report_Non_Short_Circuit_Operators
              (Unit, Node.As_If_Expr.F_Cond_Expr);
            Control_Flow.Analyze_If_Expression (Unit, Node.As_If_Expr);

         when Libadalang.Common.Ada_Elsif_Expr_Part =>
            Report_Constant_Condition
              (Unit, Node.As_Elsif_Expr_Part.F_Cond_Expr);
            Report_Non_Short_Circuit_Operators
              (Unit, Node.As_Elsif_Expr_Part.F_Cond_Expr);

         when Libadalang.Common.Ada_While_Loop_Stmt =>
            declare
               Spec : constant Libadalang.Analysis.Loop_Spec :=
                 Node.As_While_Loop_Stmt.F_Spec;
            begin
               if not Libadalang.Analysis.Is_Null (Spec) then
                  Report_Constant_Condition
                    (Unit, Spec.As_While_Loop_Spec.F_Expr);
                  Report_Non_Short_Circuit_Operators
                    (Unit, Spec.As_While_Loop_Spec.F_Expr);
               end if;
               if Rule_States (Empty_Loop) = Enabled
                 and then not Control_Flow.Has_Substantive_Statement
                   (Node.As_Base_Loop_Stmt.F_Stmts)
               then
                  Report_Rule_Violation
                    (Unit, Node, Empty_Loop,
                     "loop body contains no substantive statements");
               end if;
               Control_Flow.Analyze_Infinite_Loop
                 (Unit, Node.As_Base_Loop_Stmt);
            end;

         when Libadalang.Common.Ada_Exit_Stmt =>
            declare
               Cond : constant Libadalang.Analysis.Expr :=
                 Node.As_Exit_Stmt.F_Cond_Expr;
            begin
               if not Libadalang.Analysis.Is_Null (Cond) then
                  Report_Constant_Condition (Unit, Cond);
                  Report_Non_Short_Circuit_Operators (Unit, Cond);
               end if;
            end;

         when Libadalang.Common.Ada_Null_Stmt =>
            if Rule_States (Null_Statement) = Enabled then
               Report_Rule_Violation
                 (Unit, Node, Null_Statement,
                  "null statement has no executable effect");
            end if;

         when Libadalang.Common.Ada_Exception_Handler =>
            Control_Flow.Analyze_Exception_Handler
              (Unit, Node.As_Exception_Handler);

         when Libadalang.Common.Ada_Pragma_Node =>
            if Rule_States (Known_Assertion_Failure) = Enabled then
               declare
                  Cond : constant Libadalang.Analysis.Expr :=
                    Assertion_Expression (Node.As_Pragma_Node);
               begin
                  if not Libadalang.Analysis.Is_Null (Cond)
                    and then Boolean_Value (Cond) = Bool_False
                  then
                     Report_Rule_Violation
                       (Unit, Cond, Known_Assertion_Failure,
                        "assertion condition is statically false");
                  end if;
               end;
            end if;

         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            if Rule_States (Empty_Loop) = Enabled
              and then not Control_Flow.Has_Substantive_Statement
                (Node.As_Base_Loop_Stmt.F_Stmts)
            then
               Report_Rule_Violation
                 (Unit, Node, Empty_Loop,
                  "loop body contains no substantive statements");
            end if;
            Control_Flow.Analyze_Infinite_Loop (Unit, Node.As_Base_Loop_Stmt);

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;
   end Analyze_Bug_Finding_Node;

   --  True when Name denotes Ada.Unchecked_Conversion, either by its fully
   --  qualified spelling or, for an unqualified "Unchecked_Conversion",
   --  by resolving the name and checking its fully qualified declaration.
   --  Falls back to the qualified-spelling check alone when resolution
   --  fails, rather than risk flagging an unrelated same-named generic.
   function Is_Ada_Unchecked_Conversion
     (Name : Libadalang.Analysis.Name'Class) return Boolean
   is
      Written_Name : constant String := Canonical_Text (Name);
   begin
      if Written_Name = "ada.unchecked_conversion" then
         return True;
      elsif Written_Name /= "unchecked_conversion" then
         return False;
      end if;

      declare
         Declaration : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
         Full_Name   : constant String := Langkit_Support.Text.To_UTF8
           (Declaration.P_Canonical_Fully_Qualified_Name);
      begin
         return Full_Name = "ada.unchecked_conversion";
      end;
   exception
      when others =>
         --  Keep the qualified spelling useful even when resolution fails,
         --  but do not guess for an unrelated unqualified generic.
         return Written_Name = "ada.unchecked_conversion";
   end Is_Ada_Unchecked_Conversion;

   procedure Evaluate_Node  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Libadalang.Analysis.Is_Null (Node.Parent) then
         Declarations.Begin_Traversal;
      end if;
      Declarations.Enter_Node (Node);

      --  A semantic property query below (name resolution, expression
      --  typing, ...) can raise Property_Error on constructs Libadalang's
      --  resolution engine can't fully handle. Confine that failure to
      --  this node's own checks, rather than letting it unwind out of
      --  Process_File and abandon analysis of the rest of the file.
      begin
      if Rule_States (SPARK_Mode) = Enabled then
         if Node.Kind = Libadalang.Common.Ada_Aspect_Assoc then
            declare
               Aspect : constant Libadalang.Analysis.Aspect_Assoc :=
                 Node.As_Aspect_Assoc;
            begin
               if Canonical_Text (Aspect.F_Id) = "spark_mode"
                 and then Canonical_Text (Aspect.F_Expr) = "off"
               then
                  Report_Rule_Violation
                    (Unit, Node, SPARK_Mode,
                     "SPARK_Mode is explicitly disabled");
               end if;
            end;
         elsif Node.Kind = Libadalang.Common.Ada_Pragma_Node then
            declare
               Pragma_Node : constant Libadalang.Analysis.Pragma_Node :=
                 Node.As_Pragma_Node;
            begin
               if Canonical_Text (Pragma_Node.F_Id) = "spark_mode" then
                  for Arg of Pragma_Node.F_Args loop
                     if Canonical_Text (Arg.P_Assoc_Expr) = "off" then
                        Report_Rule_Violation
                          (Unit, Node, SPARK_Mode,
                           "SPARK_Mode is explicitly disabled");
                        exit;
                     end if;
                  end loop;
               end if;
            end;
         end if;
      end if;
      if Rule_States (No_Goto) = Enabled and then Node.Kind = Libadalang.Common.Ada_Goto_Stmt then
         Report_Rule_Violation (Unit, Node, No_Goto, "goto statement used");
      end if;
      if Rule_States (No_Abort) = Enabled and then Node.Kind = Libadalang.Common.Ada_Abort_Stmt then
         Report_Rule_Violation (Unit, Node, No_Abort, "abort statement used");
      end if;
      if Rule_States (No_Raise) = Enabled and then Node.Kind = Libadalang.Common.Ada_Raise_Stmt then
         Report_Rule_Violation (Unit, Node, No_Raise, "raise statement used");
      end if;
      if Rule_States (No_Exit) = Enabled and then Node.Kind = Libadalang.Common.Ada_Exit_Stmt then
         Report_Rule_Violation (Unit, Node, No_Exit, "exit statement used");
      end if;
      if Rule_States (No_Label) = Enabled and then Node.Kind = Libadalang.Common.Ada_Label then
         Report_Rule_Violation (Unit, Node, No_Label, "label used");
      end if;
      if Rule_States (No_Pragma) = Enabled
        and then Node.Kind = Libadalang.Common.Ada_Pragma_Node
        and then not Is_Generated_Config_File (Unit.Get_Filename)
      then
         Report_Rule_Violation (Unit, Node, No_Pragma, "pragma used");
      end if;
      if Rule_States (No_Access_To_Subp_Def) = Enabled and then Node.Kind = Libadalang.Common.Ada_Access_To_Subp_Def then
         Report_Rule_Violation (Unit, Node, No_Access_To_Subp_Def,
                                "access-to-subprogram type definition used");
      end if;
      if Rule_States (Address_Clause) = Enabled
        and then Node.Kind = Libadalang.Common.Ada_Attribute_Def_Clause
      then
         declare
            Clause     : constant Libadalang.Analysis.Attribute_Def_Clause :=
              Node.As_Attribute_Def_Clause;
            Attr_Expr  : constant Libadalang.Analysis.Name :=
              Clause.F_Attribute_Expr;
         begin
            if not Libadalang.Analysis.Is_Null (Attr_Expr)
              and then Attr_Expr.Kind = Libadalang.Common.Ada_Attribute_Ref
              and then Normalize_Rule_Name
                (Node_Text (Attr_Expr.As_Attribute_Ref.F_Attribute)) =
                "address"
            then
               Report_Rule_Violation
                 (Unit, Node, Address_Clause, "address clause used");
            end if;
         end;
      end if;
      if Rule_States (No_Unchecked_Conversion) = Enabled
        and then Node.Kind =
          Libadalang.Common.Ada_Generic_Subp_Instantiation
      then
         declare
            Generic_Name : constant Libadalang.Analysis.Name :=
              Node.As_Generic_Subp_Instantiation.F_Generic_Subp_Name;
         begin
            if Is_Ada_Unchecked_Conversion (Generic_Name) then
               Report_Rule_Violation
                 (Unit, Node, No_Unchecked_Conversion,
                  "Ada.Unchecked_Conversion instantiated");
            end if;
         end;
      end if;
      if Rule_States (Magic_Number) = Enabled
        and then Node.Kind in Libadalang.Common.Ada_Int_Literal
          | Libadalang.Common.Ada_Real_Literal
        and then not Is_Allowed_Magic_Number (Node)
      then
         Report_Rule_Violation
           (Unit, Node, Magic_Number,
            "numeric literal should be replaced by a named constant");
      end if;

      --  Apply node-specific checks before recursively visiting descendants.
      Analyze_Bug_Finding_Node (Unit, Node);
      exception
         when Exc : others =>
            Skipped_Nodes := Skipped_Nodes + 1;
            Log_Verbose
              ("skipping checks at " & Node.Image & ": " &
               Ada.Exceptions.Exception_Message (Exc));
      end;

      Declarations.Register_Declaration (Node);

      for I in 1 .. Node.Children_Count loop
         Evaluate_Node (Unit, Node.Child (I));
      end loop;
      Declarations.Leave_Node (Node);
   end Evaluate_Node;

end Adalang_Analyzer.Checks;
