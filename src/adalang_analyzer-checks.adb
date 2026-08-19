--  AdaLang Analyzer
--
--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--
--  Derived from AdaCore's libadalang-tools and substantially extended,
--  integrated, validated, and maintained by Spazio IT as part of the
--  independent AdaLang Analyzer project.
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Exceptions;
with Ada.Strings;
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
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.Report;               use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;                use Adalang_Analyzer.Rules;
with Adalang_Analyzer.SPARK_Readiness;
with Adalang_Analyzer.Subprogram_Summaries;
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
               return Ancestor.As_Object_Decl.F_Has_Constant;

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

   --  True when Expr's own resolved type is exactly Standard.Boolean.
   --  Backs Report_Non_Short_Circuit_Operators's operand-type guard: RM
   --  4.5.7 restricts the short-circuit forms "and then"/"or else" to
   --  Boolean operands, so a bitwise "and"/"or" on a modular or other
   --  non-Boolean type must not be told to use a short-circuit form it
   --  cannot legally use. Mirrors Checks.Expressions.
   --  Is_Standard_Boolean_Expression. Resolution failure is conservatively
   --  treated as "not Boolean" rather than risking a false positive.
   function Is_Standard_Boolean_Operand
     (Expr : Libadalang.Analysis.Expr'Class) return Boolean
   is
      Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
        Expr.P_Expression_Type;
   begin
      return not Libadalang.Analysis.Is_Null (Expr_Type)
        and then Langkit_Support.Text.To_UTF8
                   (Expr_Type.P_Canonical_Fully_Qualified_Name) =
                     "standard.boolean";
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping Non_Short_Circuit_Condition operand-type check: " &
            Ada.Exceptions.Exception_Message (Exc));
         return False;
   end Is_Standard_Boolean_Operand;

   --  Reports Non_Short_Circuit_Condition for every plain "and"/"or"
   --  operator anywhere within Cond's subtree. Shared by if/elsif/while/
   --  exit-when condition sites, alongside Report_Constant_Condition. Does
   --  not descend into a nested Ada_If_Expr/Ada_Elsif_Expr_Part: the
   --  generic node walker visits those independently and calls this same
   --  procedure on their own F_Cond_Expr, so descending here too would
   --  report an "and"/"or" inside a nested if-expression's condition
   --  twice.
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

      if Cond.Kind in Libadalang.Common.Ada_Bin_Op_Range
        and then Is_Standard_Boolean_Operand (Cond.As_Bin_Op.F_Left)
      then
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
         if Cond.Child (I).Kind not in
           Libadalang.Common.Ada_If_Expr
           | Libadalang.Common.Ada_Elsif_Expr_Part
         then
            Report_Non_Short_Circuit_Operators (Unit, Cond.Child (I));
         end if;
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

   --  Reports Rule for every call in Node's subtree whose callee has an
   --  out or in out parameter. Only a function can appear in an assertion
   --  condition's or entry barrier's expression syntax, so no Subp_Kind
   --  check is needed here -- but a function with an out/in-out parameter
   --  (legal since Ada 2012) can still mutate caller-visible state through
   --  it. Shared by Assertion_Side_Effect (an effect that silently stops
   --  happening if assertions are disabled) and Entry_Barrier_Side_Effect
   --  (a barrier is evaluated on every call/exit of the protected object
   --  and RM 9.5.3 requires it to be side-effect-free).
   procedure Report_Call_Side_Effects
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Node        : Libadalang.Analysis.Ada_Node'Class;
      Rule        : Rule_Kind;
      Context     : String)
   is
   begin
      if Node.Kind = Libadalang.Common.Ada_Call_Expr then
         begin
            declare
               Callee : constant Libadalang.Analysis.Basic_Decl :=
                 Node.As_Call_Expr.F_Name.P_Referenced_Decl
                   (Imprecise_Fallback => True);
            begin
               if not Libadalang.Analysis.Is_Null (Callee) then
                  declare
                     Spec : constant Libadalang.Analysis.Base_Subp_Spec :=
                       Callee.P_Subp_Spec_Or_Null;
                  begin
                     if not Libadalang.Analysis.Is_Null (Spec) then
                        for Param of Spec.P_Params loop
                           if Param.F_Mode.Kind in
                             Libadalang.Common.Ada_Mode_Out_Range
                               | Libadalang.Common.Ada_Mode_In_Out_Range
                           then
                              Report_Rule_Violation
                                (Unit, Node, Rule,
                                 Context & " calls '" &
                                   Node_Text (Node.As_Call_Expr.F_Name) &
                                   "', which has an out or in out " &
                                   "parameter and can mutate caller state");
                              exit;
                           end if;
                        end loop;
                     end if;
                  end;
               end if;
            end;
         exception
            when Exc : others =>
               Log_Verbose_Once
                 ("skipping call side-effect resolution: " &
                  Ada.Exceptions.Exception_Message (Exc));
         end;
      end if;

      for Index in 1 .. Node.Children_Count loop
         --  A positional Param_Assoc's F_Designator (among other optional
         --  fields) is null, unlike the always-present expression children
         --  Has_Classwide_Operand's identical-shaped walk normally meets;
         --  recursing into it would raise on the unguarded .Kind read
         --  above.
         if not Libadalang.Analysis.Is_Null (Node.Child (Index)) then
            Report_Call_Side_Effects (Unit, Node.Child (Index), Rule, Context);
         end if;
      end loop;
   end Report_Call_Side_Effects;

   function Has_Exception_Boundary
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;

   function Has_Classwide_Operand
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Node.Kind in Libadalang.Common.Ada_Expr then
         declare
            Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
              Node.As_Expr.P_Expression_Type;
         begin
            if not Libadalang.Analysis.Is_Null (Expr_Type)
              and then Expr_Type.Kind =
                Libadalang.Common.Ada_Classwide_Type_Decl
            then
               return True;
            end if;
         exception
            when Exc : others =>
               Log_Verbose_Once
                 ("skipping class-wide operand resolution: " &
                  Ada.Exceptions.Exception_Message (Exc));
         end;
      end if;
      for Index in 1 .. Node.Children_Count loop
         if Has_Classwide_Operand (Node.Child (Index)) then
            return True;
         end if;
      end loop;
      return False;
   end Has_Classwide_Operand;

   procedure Analyze_Automotive_Call
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Dispatching : Boolean := False;
   begin
      if Rule_States (No_Dispatching_Call) = Enabled then
         begin
            if Node.Kind = Libadalang.Common.Ada_Call_Expr then
               Dispatching :=
                 Node.As_Call_Expr.F_Name.P_Is_Dispatching_Call
                   (Imprecise_Fallback => True);
            elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt then
               declare
                  Call : constant Libadalang.Analysis.Name :=
                    Node.As_Call_Stmt.F_Call;
               begin
                  if Call.Kind = Libadalang.Common.Ada_Call_Expr then
                     Dispatching :=
                       Call.As_Call_Expr.F_Name.P_Is_Dispatching_Call
                         (Imprecise_Fallback => True);
                  else
                     Dispatching := Call.P_Is_Dispatching_Call
                       (Imprecise_Fallback => True);
                  end if;
               end;
            end if;
         exception
            when others =>
               Dispatching := False;
         end;

         if Dispatching or else Has_Classwide_Operand (Node) then
            Report_Rule_Violation
              (Unit, Node, No_Dispatching_Call,
               "dynamically dispatching call used");
         end if;
      end if;

      if Rule_States (Exception_Propagation) = Enabled
        and then not Has_Exception_Boundary (Node)
        and then Adalang_Analyzer.Subprogram_Summaries.Callee_May_Raise (Node)
      then
         Report_Rule_Violation
           (Unit, Node, Exception_Propagation,
            "call may propagate an explicitly raised exception");
      end if;
   end Analyze_Automotive_Call;

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
            if Node.As_Call_Stmt.F_Call.Kind /=
              Libadalang.Common.Ada_Call_Expr
            then
               Analyze_Automotive_Call (Unit, Node);
            end if;

         when Libadalang.Common.Ada_Object_Decl =>
            Declarations.Analyze_Object_Declaration
              (Unit, Node.As_Object_Decl);

         when Libadalang.Common.Ada_Subp_Body =>
            Declarations.Analyze_Subprogram (Unit, Node.As_Subp_Body);

         when Libadalang.Common.Ada_Classic_Subp_Decl =>
            Declarations.Analyze_Subprogram_Declaration
              (Unit, Node.As_Classic_Subp_Decl);

         when Libadalang.Common.Ada_Case_Stmt =>
            Control_Flow.Analyze_Case_Statement (Unit, Node.As_Case_Stmt);

         when Libadalang.Common.Ada_Dotted_Name =>
            if Rule_States (Known_Discriminant_Check_Failure) = Enabled then
               SPARK_Readiness.Check_Discriminant_Access
                 (Unit, Node.As_Dotted_Name);
            end if;

         when Libadalang.Common.Ada_Call_Expr =>
            Analyze_Automotive_Call (Unit, Node);
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
               Control_Flow.Analyze_Loop_Variant_Presence
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

         when Libadalang.Common.Ada_Entry_Body =>
            if Rule_States (Entry_Barrier_Side_Effect) = Enabled then
               declare
                  Barrier : constant Libadalang.Analysis.Expr :=
                    Node.As_Entry_Body.F_Barrier;
               begin
                  if not Libadalang.Analysis.Is_Null (Barrier) then
                     Report_Call_Side_Effects
                       (Unit, Barrier, Entry_Barrier_Side_Effect,
                        "entry barrier condition");
                  end if;
               end;
            end if;

         when Libadalang.Common.Ada_Pragma_Node =>
            if Rule_States (Known_Assertion_Failure) = Enabled
              or else Rule_States (Assertion_Side_Effect) = Enabled
            then
               declare
                  Cond : constant Libadalang.Analysis.Expr :=
                    Assertion_Expression (Node.As_Pragma_Node);
               begin
                  if not Libadalang.Analysis.Is_Null (Cond) then
                     if Rule_States (Assertion_Side_Effect) = Enabled then
                        Report_Call_Side_Effects
                          (Unit, Cond, Assertion_Side_Effect,
                           "assertion condition");
                     end if;

                     if Rule_States (Known_Assertion_Failure) = Enabled then
                        if Boolean_Value (Cond) = Bool_False then
                           Adalang_Analyzer.Proof_Obligations.Register_At
                             (Unit           => Unit,
                              Node           => Cond,
                              Kind           =>
                                Adalang_Analyzer.Proof_Obligations
                                  .Assertion_Check,
                              Status         =>
                                Adalang_Analyzer.Proof_Obligations
                                  .Definite_Error,
                              Method         =>
                                Adalang_Analyzer.Proof_Obligations
                                  .Static_Evaluation,
                              Abstract_State => "assertion condition => false",
                              Explanation    =>
                                "assertion condition is statically false",
                              Configuration_Id => Assurance_Profile_Name);
                           Report_Rule_Violation
                             (Unit, Cond, Known_Assertion_Failure,
                              "assertion condition is statically false",
                              Explanation =>
                                "Static evaluation resolved the assertion " &
                                "condition to False.",
                              Evidence => "assertion condition => false");
                        else
                           Adalang_Analyzer.Proof_Obligations.Register_At
                             (Unit         => Unit,
                              Node         => Cond,
                              Kind         =>
                                Adalang_Analyzer.Proof_Obligations
                                  .Assertion_Check,
                              Status       =>
                                Adalang_Analyzer.Proof_Obligations.Unproved,
                              Method       =>
                                Adalang_Analyzer.Proof_Obligations
                                  .Static_Evaluation,
                              Explanation  =>
                                "assertion failure is not established, " &
                                "but the assertion is not proved",
                              Imprecision_Source =>
                                "static evaluation is inconclusive",
                              Configuration_Id => Assurance_Profile_Name);
                        end if;
                     end if;
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
            Control_Flow.Analyze_Loop_Variant_Presence
              (Unit, Node.As_Base_Loop_Stmt);

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

   function Is_Ada_Unchecked_Deallocation
     (Name : Libadalang.Analysis.Name'Class) return Boolean
   is
      Written_Name : constant String := Canonical_Text (Name);
   begin
      if Written_Name = "ada.unchecked_deallocation" then
         return True;
      elsif Written_Name /= "unchecked_deallocation" then
         return False;
      end if;

      declare
         Declaration : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
         Full_Name   : constant String := Langkit_Support.Text.To_UTF8
           (Declaration.P_Canonical_Fully_Qualified_Name);
      begin
         return Full_Name = "ada.unchecked_deallocation";
      end;
   exception
      when others =>
         return Written_Name = "ada.unchecked_deallocation";
   end Is_Ada_Unchecked_Deallocation;

   function Is_Controlled_Type
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Text : constant String := Ada.Characters.Handling.To_Lower
        (Node_Text (Node));
   begin
      if Node.Kind not in Libadalang.Common.Ada_Base_Type_Decl then
         return False;
      end if;
      for Base of Node.As_Base_Type_Decl.P_Base_Types loop
         declare
            Name : constant String := Ada.Characters.Handling.To_Lower
              (Langkit_Support.Text.To_UTF8
                 (Base.P_Canonical_Fully_Qualified_Name));
         begin
            if Name = "ada.finalization.controlled"
              or else Name = "ada.finalization.limited_controlled"
            then
               return True;
            end if;
         end;
      end loop;
      return Ada.Strings.Fixed.Index
        (Text, "ada.finalization.controlled") /= 0
        or else Ada.Strings.Fixed.Index
          (Text, "ada.finalization.limited_controlled") /= 0;
   exception
      when others =>
         return False;
   end Is_Controlled_Type;

   function Has_Exception_Boundary
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Node);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Handled_Stmts
           and then Current.As_Handled_Stmts.F_Exceptions.Children_Count > 0
         then
            return True;
         elsif Current.Kind in Libadalang.Common.Ada_Subp_Body
                              | Libadalang.Common.Ada_Task_Body
         then
            --  A task runs on its own thread of control: an exception
            --  handler lexically enclosing the task body (e.g. on a
            --  declare block or subprogram the task type/object happens
            --  to be declared within) can never catch an exception raised
            --  during the task's own independent execution, so the walk
            --  must not cross this boundary the way it legitimately does
            --  for ordinary nested scopes.
            return False;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Has_Exception_Boundary;

   function Contains_Call
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr
        and then Node.As_Call_Expr.F_Name.Kind =
          Libadalang.Common.Ada_Attribute_Ref
      then
         --  Attribute evaluation uses call-like syntax in Libadalang, but
         --  does not call another library unit and therefore introduces no
         --  elaboration-order dependency. Its prefix and arguments can still
         --  contain real calls, so inspect the children.
         for Index in 1 .. Node.Children_Count loop
            if Contains_Call (Node.Child (Index)) then
               return True;
            end if;
         end loop;
         return False;
      elsif Node.Kind in
        Libadalang.Common.Ada_Call_Expr
          | Libadalang.Common.Ada_Dotted_Name
          | Libadalang.Common.Ada_Identifier
      then
         begin
            if Node.As_Name.P_Is_Call then
               --  Libadalang models enumeration literals as parameterless
               --  calls. They are static values, however, and do not create
               --  elaboration-order dependencies.
               if Node.Kind in
                 Libadalang.Common.Ada_Dotted_Name
                   | Libadalang.Common.Ada_Identifier
               then
                  declare
                     Decl : constant Libadalang.Analysis.Basic_Decl :=
                       Node.As_Name.P_Referenced_Decl
                         (Imprecise_Fallback => True);
                  begin
                     if not Libadalang.Analysis.Is_Null (Decl)
                       and then Decl.Kind in
                         Libadalang.Common.Ada_Enum_Literal_Decl_Range
                     then
                        return False;
                     end if;
                  end;
               end if;
               return True;
            end if;
         exception
            when Exc : others =>
               Log_Verbose_Once
                 ("skipping call resolution: " &
                  Ada.Exceptions.Exception_Message (Exc));
         end;
      end if;
      for Index in 1 .. Node.Children_Count loop
         if Contains_Call (Node.Child (Index)) then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Call;

   function Is_Library_Level
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Subp_Body
           or else Current.Kind = Libadalang.Common.Ada_Task_Body
           or else Current.Kind = Libadalang.Common.Ada_Entry_Body
         then
            return False;
         elsif Current.Kind = Libadalang.Common.Ada_Package_Decl
           or else Current.Kind = Libadalang.Common.Ada_Package_Body
         then
            return True;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_Library_Level;

   function Count_Kind
     (Node : Libadalang.Analysis.Ada_Node'Class;
      First, Last : Libadalang.Common.Ada_Node_Kind_Type) return Natural
   is
      Result : Natural := 0;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return 0;
      end if;
      if Node.Kind in First .. Last then
         Result := 1;
      end if;
      for Index in 1 .. Node.Children_Count loop
         Result := Result + Count_Kind (Node.Child (Index), First, Last);
      end loop;
      return Result;
   end Count_Kind;

   function Has_Ancestor
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Kind : Libadalang.Common.Ada_Node_Kind_Type) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Kind then
            return True;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Has_Ancestor;

   function Is_Language_Defined_Pragma (Name : String) return Boolean is
   begin
      return Name = "all_calls_remote"
        or else Name = "assert"
        or else Name = "assertion_policy"
        or else Name = "asynchronous"
        or else Name = "atomic"
        or else Name = "atomic_components"
        or else Name = "attach_handler"
        or else Name = "convention"
        or else Name = "cpu"
        or else Name = "detect_blocking"
        or else Name = "discard_names"
        or else Name = "elaborate"
        or else Name = "elaborate_all"
        or else Name = "elaborate_body"
        or else Name = "export"
        or else Name = "import"
        or else Name = "independent"
        or else Name = "independent_components"
        or else Name = "inline"
        or else Name = "inspection_point"
        or else Name = "interrupt_handler"
        or else Name = "interrupt_priority"
        or else Name = "list"
        or else Name = "locking_policy"
        or else Name = "no_return"
        or else Name = "normalize_scalars"
        or else Name = "optimize"
        or else Name = "pack"
        or else Name = "page"
        or else Name = "partition_elaboration_policy"
        or else Name = "preelaborable_initialization"
        or else Name = "preelaborate"
        or else Name = "priority"
        or else Name = "profile"
        or else Name = "pure"
        or else Name = "queuing_policy"
        or else Name = "relative_deadline"
        or else Name = "remote_call_interface"
        or else Name = "remote_types"
        or else Name = "restrictions"
        or else Name = "reviewable"
        or else Name = "shared_passive"
        or else Name = "storage_size"
        or else Name = "suppress"
        or else Name = "task_dispatching_policy"
        or else Name = "unchecked_union"
        or else Name = "unsuppress"
        or else Name = "volatile"
        or else Name = "volatile_components";
   end Is_Language_Defined_Pragma;

   --  Bit width of Typ when it is one of the eight predefined Interfaces
   --  modular/signed types (RM B.2) that Shift_Left/Shift_Right/
   --  Shift_Right_Arithmetic/Rotate_Left/Rotate_Right operate on, 0
   --  otherwise. Deliberately narrow: a user-defined type with its own
   --  same-named operation is not this attribute's concern, and guessing
   --  its width from an arbitrary representation clause would risk a
   --  wrong verdict rather than just missing one.
   function Interfaces_Shift_Rotate_Bit_Width
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return Natural
   is
   begin
      if Libadalang.Analysis.Is_Null (Typ) then
         return 0;
      end if;

      declare
         Name : constant String := Langkit_Support.Text.To_UTF8
           (Typ.P_Canonical_Fully_Qualified_Name);
      begin
         if Name in "interfaces.unsigned_8" | "interfaces.integer_8" then
            return 8;
         elsif Name in
           "interfaces.unsigned_16" | "interfaces.integer_16"
         then
            return 16;
         elsif Name in
           "interfaces.unsigned_32" | "interfaces.integer_32"
         then
            return 32;
         elsif Name in
           "interfaces.unsigned_64" | "interfaces.integer_64"
         then
            return 64;
         else
            return 0;
         end if;
      end;
   exception
      when others =>
         return 0;
   end Interfaces_Shift_Rotate_Bit_Width;

   function Has_Requirement_Trace
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Marker     : constant String := "do-178c: req";
      Start_Line : constant Natural :=
        Natural (Node.Sloc_Range.Start_Line);
   begin
      for Offset in Natural range 0 .. 3 loop
         exit when Offset >= Start_Line;
         declare
            Line : constant String :=
              Ada.Characters.Handling.To_Lower
                (Source_Line (Unit.Get_Filename, Start_Line - Offset));
            Position : constant Natural :=
              Ada.Strings.Fixed.Index (Line, Marker);
         begin
            if Position > 0 then
               declare
                  First : constant Natural := Position + Marker'Length;
               begin
                  return First <= Line'Last
                    and then Ada.Strings.Fixed.Trim
                      (Line (First .. Line'Last), Ada.Strings.Both) /= "";
               end;
            end if;
         end;
      end loop;
      return False;
   end Has_Requirement_Trace;

   procedure Evaluate_Node  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Libadalang.Analysis.Is_Null (Node.Parent) then
         Declarations.Begin_Traversal;
         if Rule_States (Generic_Instantiation_Limit) = Enabled then
            declare
               Total : constant Natural := Count_Kind
                 (Node, Libadalang.Common.Ada_Generic_Package_Instantiation,
                  Libadalang.Common.Ada_Generic_Subp_Instantiation);
            begin
               if Total > Generic_Threshold then
                  Report_Rule_Violation
                    (Unit, Node, Generic_Instantiation_Limit,
                     "unit has " & To_Decimal (Total) &
                       " generic instantiations; threshold is " &
                       To_Decimal (Generic_Threshold));
               end if;
            end;
         end if;
         if Rule_States (Dependency_Limit) = Enabled then
            declare
               Total : constant Natural := Count_Kind
                 (Node, Libadalang.Common.Ada_With_Clause,
                  Libadalang.Common.Ada_With_Clause);
            begin
               if Total > Dependency_Threshold then
                  Report_Rule_Violation
                    (Unit, Node, Dependency_Limit,
                     "unit has " & To_Decimal (Total) &
                       " with-clause dependencies; threshold is " &
                       To_Decimal (Dependency_Threshold));
               end if;
            end;
         end if;
      end if;
      Declarations.Enter_Node (Node);

      --  A semantic property query below (name resolution, expression
      --  typing, ...) can raise Property_Error on constructs Libadalang's
      --  resolution engine can't fully handle. Confine that failure to
      --  this node's own checks, rather than letting it unwind out of
      --  Process_File and abandon analysis of the rest of the file.
      begin
         if Rule_States (Missing_Requirement_Trace) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Subp_Body
           and then not Has_Requirement_Trace (Unit, Node)
         then
            Report_Rule_Violation
              (Unit, Node, Missing_Requirement_Trace,
               "subprogram has no DO-178C low-level requirement trace");
         end if;
         if Rule_States (Redundant_Final_Return) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Subp_Body
         then
            declare
               Stmts : constant Libadalang.Analysis.Stmt_List :=
                 Node.As_Subp_Body.F_Stmts.F_Stmts;
            begin
               if Stmts.Children_Count > 0
                 and then Stmts.Child (Stmts.Children_Count).Kind =
                   Libadalang.Common.Ada_Return_Stmt
                 and then Libadalang.Analysis.Is_Null
                   (Stmts.Child
                      (Stmts.Children_Count).As_Return_Stmt.F_Return_Expr)
               then
                  Report_Rule_Violation
                    (Unit, Stmts.Child (Stmts.Children_Count),
                     Redundant_Final_Return,
                     "redundant 'return;' as the last statement of the " &
                     "procedure body");
               end if;
            end;
         end if;
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
         if Rule_States (No_Compiler_Extensions) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Pragma_Node
           and then not Is_Generated_Config_File (Unit.Get_Filename)
         then
            declare
               Name : constant String := Normalize_Rule_Name
                 (Node_Text (Node.As_Pragma_Node.F_Id));
            begin
               if not Is_Language_Defined_Pragma (Name)
               then
                  Report_Rule_Violation
                    (Unit, Node, No_Compiler_Extensions,
                     "implementation-defined pragma " & Name & " used");
               end if;
            end;
         end if;
         if Rule_States (No_Runtime_Check_Suppression) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Pragma_Node
         then
            declare
               Pragma_Node : constant Libadalang.Analysis.Pragma_Node :=
                 Node.As_Pragma_Node;
               Name : constant String :=
                 Normalize_Rule_Name (Node_Text (Pragma_Node.F_Id));

               function Disables_Check return Boolean is
               begin
                  if Pragma_Node.F_Args.Children_Count < 2 then
                     return False;
                  end if;

                  declare
                     Policy : constant String :=
                       Normalize_Rule_Name
                         (Node_Text
                            (Pragma_Node.F_Args.Child
                               (Pragma_Node.F_Args.Children_Count)
                               .As_Pragma_Argument_Assoc.P_Assoc_Expr));
                  begin
                     return Policy = "ignore" or else Policy = "off";
                  end;
               exception
                  when others =>
                     return False;
               end Disables_Check;

               Ignoring_Check : constant Boolean :=
                 Name = "check-policy"
                 and then Disables_Check;
            begin
               if Name = "suppress"
                 or else Name = "suppress-all"
                 or else Ignoring_Check
               then
                  Report_Rule_Violation
                    (Unit, Node, No_Runtime_Check_Suppression,
                     "run-time check suppression pragma " & Name & " used");
               end if;
            end;
         end if;
         if Rule_States (Naming_Convention) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Defining_Name
           and then Node_Text (Node)'Length = 1
           and then not Has_Ancestor
             (Node, Libadalang.Common.Ada_For_Loop_Var_Decl)
           and then not Has_Ancestor
             (Node, Libadalang.Common.Ada_Enum_Literal_Decl)
         then
            Report_Rule_Violation
              (Unit, Node, Naming_Convention,
               "one-character identifier '" & Node_Text (Node) & "' used");
         end if;
         if Rule_States (No_Access_To_Subp_Def) = Enabled
           and then Node.Kind =
             Libadalang.Common.Ada_Access_To_Subp_Def
         then
            Report_Rule_Violation
              (Unit, Node, No_Access_To_Subp_Def,
               "access-to-subprogram type definition used");
         end if;
         if Rule_States (No_Dynamic_Allocation) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Allocator
         then
            Report_Rule_Violation
              (Unit, Node, No_Dynamic_Allocation, "dynamic allocator used");
         end if;
         if Rule_States (Restricted_Access_Type) = Enabled
           and then Node.Kind in
             Libadalang.Common.Ada_Anonymous_Type_Access_Def
               | Libadalang.Common.Ada_Type_Access_Def
         then
            Report_Rule_Violation
              (Unit, Node, Restricted_Access_Type,
               "access-to-object type definition used");
         end if;
         if Rule_States (No_Explicit_Dereference) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Explicit_Deref
         then
            Report_Rule_Violation
              (Unit, Node, No_Explicit_Dereference,
               "explicit access-value dereference used");
         end if;
         if Rule_States (No_Tasking) = Enabled
           and then Node.Kind in Libadalang.Common.Ada_Task_Type_Decl
             | Libadalang.Common.Ada_Single_Task_Decl
         then
            Report_Rule_Violation
              (Unit, Node, No_Tasking, "task declaration used");
         end if;
         if Rule_States (No_Rendezvous) = Enabled
           and then Node.Kind in Libadalang.Common.Ada_Entry_Decl
             | Libadalang.Common.Ada_Accept_Stmt_Range
         then
            Report_Rule_Violation
              (Unit, Node, No_Rendezvous,
               (if Node.Kind = Libadalang.Common.Ada_Entry_Decl
                then "task entry declared"
                else "accept statement used"));
         end if;
         if Rule_States (No_Select) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Select_Stmt
         then
            Report_Rule_Violation
              (Unit, Node, No_Select, "select statement used");
         end if;
         if Rule_States (No_Requeue) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Requeue_Stmt
         then
            Report_Rule_Violation
              (Unit, Node, No_Requeue, "requeue statement used");
         end if;
         if Rule_States (No_Asynchronous_Transfer) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Then_Abort_Part
         then
            Report_Rule_Violation
              (Unit, Node, No_Asynchronous_Transfer,
               "asynchronous transfer of control used");
         end if;
         if Rule_States (No_Classwide_Type) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Attribute_Ref
           and then Normalize_Rule_Name
             (Node_Text (Node.As_Attribute_Ref.F_Attribute)) = "class"
         then
            Report_Rule_Violation
              (Unit, Node, No_Classwide_Type, "class-wide type used");
         end if;
         if Rule_States (No_Unchecked_Access) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Attribute_Ref
           and then Normalize_Rule_Name
             (Node_Text (Node.As_Attribute_Ref.F_Attribute)) =
             "unchecked-access"
         then
            Report_Rule_Violation
              (Unit, Node, No_Unchecked_Access,
               "'Unchecked_Access attribute used");
         end if;
         if Rule_States (Succ_Pred_Boundary_Overflow) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Call_Expr
           and then Node.As_Call_Expr.F_Name.Kind =
             Libadalang.Common.Ada_Attribute_Ref
           and then Node.As_Call_Expr.F_Suffix.Kind in
             Libadalang.Common.Ada_Basic_Assoc_List
           and then Node.As_Call_Expr.F_Suffix.Children_Count = 1
           and then Node.As_Call_Expr.F_Suffix.Child (1).Kind =
             Libadalang.Common.Ada_Param_Assoc
         then
            declare
               Attr      : constant Libadalang.Analysis.Attribute_Ref :=
                 Node.As_Call_Expr.F_Name.As_Attribute_Ref;
               Attr_Name : constant String :=
                 Normalize_Rule_Name (Node_Text (Attr.F_Attribute));
               Arg       : constant Libadalang.Analysis.Expr :=
                 Node.As_Call_Expr.F_Suffix.Child
                   (1).As_Param_Assoc.F_R_Expr;
            begin
               if Attr_Name in "succ" | "pred"
                 and then not Libadalang.Analysis.Is_Null (Arg)
                 and then Arg.Kind = Libadalang.Common.Ada_Attribute_Ref
               then
                  declare
                     Arg_Attr : constant Libadalang.Analysis.Attribute_Ref :=
                       Arg.As_Attribute_Ref;
                     Arg_Name : constant String :=
                       Normalize_Rule_Name (Node_Text (Arg_Attr.F_Attribute));
                  begin
                     if ((Attr_Name = "succ" and then Arg_Name = "last")
                           or else
                         (Attr_Name = "pred" and then Arg_Name = "first"))
                       and then Canonical_Text (Attr.F_Prefix) /= ""
                       and then Canonical_Text (Attr.F_Prefix) =
                         Canonical_Text (Arg_Attr.F_Prefix)
                     then
                        Report_Rule_Violation
                          (Unit, Node, Succ_Pred_Boundary_Overflow,
                           "'" &
                           (if Attr_Name = "succ" then "Succ" else "Pred") &
                           " applied to the type's own '" &
                           (if Attr_Name = "succ" then "Last" else "First") &
                           " always raises Constraint_Error");
                     end if;
                  end;
               end if;
            end;
         end if;
         if Rule_States (Known_Enum_Val_Failure) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Call_Expr
           and then Node.As_Call_Expr.F_Name.Kind =
             Libadalang.Common.Ada_Attribute_Ref
           and then Node.As_Call_Expr.F_Suffix.Kind in
             Libadalang.Common.Ada_Basic_Assoc_List
           and then Node.As_Call_Expr.F_Suffix.Children_Count = 1
           and then Node.As_Call_Expr.F_Suffix.Child (1).Kind =
             Libadalang.Common.Ada_Param_Assoc
         then
            declare
               Attr : constant Libadalang.Analysis.Attribute_Ref :=
                 Node.As_Call_Expr.F_Name.As_Attribute_Ref;
            begin
               if Normalize_Rule_Name (Node_Text (Attr.F_Attribute)) =
                 "val"
                 and then not Libadalang.Analysis.Is_Null (Attr.F_Prefix)
               then
                  declare
                     Arg : constant Libadalang.Analysis.Expr :=
                       Node.As_Call_Expr.F_Suffix.Child
                         (1).As_Param_Assoc.F_R_Expr;
                     Arg_Value : constant Abstract_Int := Integer_Value (Arg);
                  begin
                     if Arg_Value.Known then
                        declare
                           Prefix_Decl :
                             constant Libadalang.Analysis.Basic_Decl :=
                             Attr.F_Prefix.P_Referenced_Decl
                               (Imprecise_Fallback => True);
                        begin
                           if not Libadalang.Analysis.Is_Null (Prefix_Decl)
                             and then Prefix_Decl.Kind in
                               Libadalang.Common.Ada_Type_Decl
                             and then Prefix_Decl.As_Type_Decl.F_Type_Def
                               .Kind = Libadalang.Common.Ada_Enum_Type_Def

                             --  Standard's predefined character types are
                             --  synthesized with a placeholder literal list
                             --  rather than one node per position, so their
                             --  Children_Count does not reflect the type's
                             --  true (256/65536-position) range -- exclude
                             --  them rather than risk a false positive on
                             --  every ordinary use.
                             and then Langkit_Support.Text.To_UTF8
                               (Prefix_Decl.P_Canonical_Fully_Qualified_Name)
                               not in
                               "standard.character" |
                               "standard.wide_character" |
                               "standard.wide_wide_character"
                           then
                              declare
                                 Literal_Count : constant Natural :=
                                   Prefix_Decl.As_Type_Decl.F_Type_Def
                                     .As_Enum_Type_Def.F_Enum_Literals
                                     .Children_Count;
                              begin
                                 if Literal_Count > 0
                                   and then
                                     (Arg_Value.Value < 0
                                        or else Arg_Value.Value >
                                          Long_Long_Integer
                                            (Literal_Count - 1))
                                 then
                                    Report_Rule_Violation
                                      (Unit, Node, Known_Enum_Val_Failure,
                                       "'Val argument" &
                                       Arg_Value.Value'Image &
                                       " is outside the type's valid " &
                                       "position range 0 .." &
                                       Natural'Image (Literal_Count - 1),
                                       Explanation =>
                                         "'Val requires its argument to " &
                                         "be a valid enumeration " &
                                         "position of the prefix type; " &
                                         "any other value raises " &
                                         "Constraint_Error.");
                                 end if;
                              end;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end if;
         if Rule_States (Known_Value_Conversion_Failure) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Call_Expr
           and then Node.As_Call_Expr.F_Name.Kind =
             Libadalang.Common.Ada_Attribute_Ref
           and then Node.As_Call_Expr.F_Suffix.Kind in
             Libadalang.Common.Ada_Basic_Assoc_List
           and then Node.As_Call_Expr.F_Suffix.Children_Count = 1
           and then Node.As_Call_Expr.F_Suffix.Child (1).Kind =
             Libadalang.Common.Ada_Param_Assoc
         then
            declare
               Attr : constant Libadalang.Analysis.Attribute_Ref :=
                 Node.As_Call_Expr.F_Name.As_Attribute_Ref;
            begin
               if Normalize_Rule_Name (Node_Text (Attr.F_Attribute)) =
                 "value"
                 and then not Libadalang.Analysis.Is_Null (Attr.F_Prefix)
               then
                  declare
                     Arg : constant Libadalang.Analysis.Expr :=
                       Node.As_Call_Expr.F_Suffix.Child
                         (1).As_Param_Assoc.F_R_Expr;
                  begin
                     if not Libadalang.Analysis.Is_Null (Arg)
                       and then Arg.Kind =
                         Libadalang.Common.Ada_String_Literal
                     then
                        declare
                           Trimmed : constant String :=
                             Ada.Strings.Fixed.Trim
                               (Langkit_Support.Text.To_UTF8
                                  (Arg.As_String_Literal.P_Denoted_Value),
                                Ada.Strings.Both);
                           Prefix_Decl :
                             constant Libadalang.Analysis.Basic_Decl :=
                             Attr.F_Prefix.P_Referenced_Decl
                               (Imprecise_Fallback => True);
                        begin
                           if not Libadalang.Analysis.Is_Null (Prefix_Decl)
                             and then Prefix_Decl.Kind in
                               Libadalang.Common.Ada_Type_Decl
                           then
                              if Prefix_Decl.As_Type_Decl.F_Type_Def.Kind =
                                Libadalang.Common.Ada_Enum_Type_Def
                                and then Langkit_Support.Text.To_UTF8
                                  (Prefix_Decl
                                     .P_Canonical_Fully_Qualified_Name)
                                  not in
                                  "standard.character" |
                                  "standard.wide_character" |
                                  "standard.wide_wide_character"
                              then
                                 declare
                                    Literals :
                                      constant Libadalang.Analysis
                                        .Enum_Literal_Decl_List :=
                                      Prefix_Decl.As_Type_Decl.F_Type_Def
                                        .As_Enum_Type_Def.F_Enum_Literals;
                                    Has_Char_Literal : Boolean := False;
                                    Matches          : Boolean := False;
                                 begin
                                    for Index in
                                      1 .. Literals.Children_Count
                                    loop
                                       declare
                                          Lit_Text : constant String :=
                                            Node_Text
                                              (Literals.Child
                                                 (Index).As_Enum_Literal_Decl
                                                 .F_Name);
                                       begin
                                          if Lit_Text'Length > 0
                                            and then Lit_Text
                                                (Lit_Text'First) = '''
                                          then
                                             Has_Char_Literal := True;
                                          elsif Ada.Characters.Handling
                                            .To_Lower (Lit_Text) =
                                            Ada.Characters.Handling.To_Lower
                                              (Trimmed)
                                          then
                                             Matches := True;
                                          end if;
                                       end;
                                    end loop;
                                    if not Has_Char_Literal
                                      and then not Matches
                                    then
                                       Report_Rule_Violation
                                         (Unit, Node,
                                          Known_Value_Conversion_Failure,
                                          "'Value string """ & Trimmed &
                                          """ names no literal of the " &
                                          "prefix enumeration type",
                                          Explanation =>
                                            "'Value requires its " &
                                            "argument, once leading and " &
                                            "trailing blanks are removed, " &
                                            "to name (case-insensitively) " &
                                            "one of the type's literals; " &
                                            "any other value raises " &
                                            "Constraint_Error.");
                                    end if;
                                 end;
                              elsif Prefix_Decl.As_Type_Decl.P_Is_Int_Type
                              then
                                 declare
                                    Malformed : Boolean := False;
                                    First     : Positive := Trimmed'First;
                                 begin
                                    if Trimmed'Length = 0 then
                                       Malformed := True;
                                    else
                                       if Trimmed (First) in '+' | '-' then
                                          First := First + 1;
                                       end if;
                                       if First > Trimmed'Last then
                                          Malformed := True;
                                       else
                                          for I in First .. Trimmed'Last
                                          loop
                                             if Trimmed (I) not in
                                               '0' .. '9' | 'a' .. 'f' |
                                               'A' .. 'F' | '_' | '#' |
                                               'e' | 'E'
                                             then
                                                Malformed := True;
                                             end if;
                                          end loop;
                                       end if;
                                    end if;
                                    if Malformed then
                                       Report_Rule_Violation
                                         (Unit, Node,
                                          Known_Value_Conversion_Failure,
                                          "'Value string """ & Trimmed &
                                          """ cannot denote any value of " &
                                          "the prefix integer type",
                                          Explanation =>
                                            "'Value requires its " &
                                            "argument, once leading and " &
                                            "trailing blanks are removed, " &
                                            "to be an optionally signed " &
                                            "numeric literal; this text " &
                                            "does not have that shape, so " &
                                            "the call always raises " &
                                            "Constraint_Error.");
                                    end if;
                                 end;
                              end if;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end if;
         if Rule_States (Excessive_Shift_Amount) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Call_Expr
           and then Node.As_Call_Expr.F_Suffix.Kind in
             Libadalang.Common.Ada_Basic_Assoc_List
           and then Node.As_Call_Expr.F_Suffix.Children_Count = 2
         then
            declare
               Call   : constant Libadalang.Analysis.Call_Expr :=
                 Node.As_Call_Expr;
               Callee : constant Libadalang.Analysis.Basic_Decl :=
                 Call.F_Name.P_Referenced_Decl (Imprecise_Fallback => True);
            begin
               if not Libadalang.Analysis.Is_Null (Callee) then
                  declare
                     Qualified_Name : constant String :=
                       Langkit_Support.Text.To_UTF8
                         (Callee.P_Canonical_Fully_Qualified_Name);
                  begin
                     if Qualified_Name in
                       "interfaces.shift_left" | "interfaces.shift_right" |
                       "interfaces.shift_right_arithmetic" |
                       "interfaces.rotate_left" | "interfaces.rotate_right"
                       and then Call.F_Suffix.Child (1).Kind =
                         Libadalang.Common.Ada_Param_Assoc
                       and then Call.F_Suffix.Child (2).Kind =
                         Libadalang.Common.Ada_Param_Assoc
                     then
                        declare
                           Value_Expr  : constant Libadalang.Analysis.Expr :=
                             Call.F_Suffix.Child (1).As_Param_Assoc.F_R_Expr;
                           Amount_Expr : constant Libadalang.Analysis.Expr :=
                             Call.F_Suffix.Child (2).As_Param_Assoc.F_R_Expr;
                           Width       : constant Natural :=
                             Interfaces_Shift_Rotate_Bit_Width
                               (Value_Expr.P_Expression_Type);
                           Amount_Val  : constant Abstract_Int :=
                             Integer_Value (Amount_Expr);
                        begin
                           if Width > 0
                             and then Amount_Val.Known
                             and then Amount_Val.Value >=
                               Long_Long_Integer (Width)
                           then
                              Report_Rule_Violation
                                (Unit, Node, Excessive_Shift_Amount,
                                 "shift/rotate amount is not less than " &
                                 "the operand's " & Width'Image &
                                 "-bit width");
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end if;

         --  A negative shift/rotate amount fails Libadalang's own
         --  overload-candidate filtering: every Interfaces shift/rotate
         --  function's Amount parameter is subtype Natural, so a
         --  statically-negative actual disqualifies *every* overload,
         --  leaving Call.F_Name.P_Referenced_Decl null -- the very
         --  Qualified_Name lookup Excessive_Shift_Amount above relies on
         --  never succeeds for this case (confirmed by direct testing, not
         --  just documentation). Detected here independently of callee
         --  resolution: the first actual's own type (Value_Expr, resolved
         --  on its own) already pins this down to a genuine Interfaces
         --  shift/rotate call precisely enough that a syntactic name match
         --  on the callee carries negligible false-positive risk.
         if Rule_States (Known_Negative_Shift_Amount_Failure) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Call_Expr
           and then Node.As_Call_Expr.F_Suffix.Kind in
             Libadalang.Common.Ada_Basic_Assoc_List
           and then Node.As_Call_Expr.F_Suffix.Children_Count = 2
           and then Node.As_Call_Expr.F_Suffix.Child (1).Kind =
             Libadalang.Common.Ada_Param_Assoc
           and then Node.As_Call_Expr.F_Suffix.Child (2).Kind =
             Libadalang.Common.Ada_Param_Assoc
         then
            declare
               Call        : constant Libadalang.Analysis.Call_Expr :=
                 Node.As_Call_Expr;
               Callee_Name : constant String :=
                 (if Call.F_Name.Kind = Libadalang.Common.Ada_Identifier
                  then Normalize_Rule_Name (Node_Text (Call.F_Name))
                  elsif Call.F_Name.Kind = Libadalang.Common.Ada_Dotted_Name
                  then Normalize_Rule_Name
                      (Node_Text (Call.F_Name.As_Dotted_Name.F_Suffix))
                  else "");
            begin
               if Callee_Name in
                 "shift-left" | "shift-right" | "shift-right-arithmetic" |
                 "rotate-left" | "rotate-right"
               then
                  declare
                     Value_Expr  : constant Libadalang.Analysis.Expr :=
                       Call.F_Suffix.Child (1).As_Param_Assoc.F_R_Expr;
                     Amount_Expr : constant Libadalang.Analysis.Expr :=
                       Call.F_Suffix.Child (2).As_Param_Assoc.F_R_Expr;
                     Width       : constant Natural :=
                       Interfaces_Shift_Rotate_Bit_Width
                         (Value_Expr.P_Expression_Type);
                     Amount_Val  : constant Abstract_Int :=
                       Integer_Value (Amount_Expr);
                  begin
                     if Width > 0
                       and then Amount_Val.Known
                       and then Amount_Val.Value < 0
                     then
                        Report_Rule_Violation
                          (Unit, Node, Known_Negative_Shift_Amount_Failure,
                           "shift/rotate amount " & Amount_Val.Value'Image &
                           " is negative",
                           Explanation =>
                             "Every Interfaces shift/rotate function's " &
                             "Amount parameter is subtype Natural; a " &
                             "negative actual fails that range check " &
                             "before the shift/rotate runs.");
                     end if;
                  end;
               end if;
            end;
         end if;

         if Rule_States (No_Controlled_Type) = Enabled
           and then Node.Kind in Libadalang.Common.Ada_Base_Type_Decl
           and then Is_Controlled_Type (Node)
         then
            Report_Rule_Violation
              (Unit, Node, No_Controlled_Type,
               "type derives from a controlled finalization type");
         end if;
         if Rule_States (Complete_Initialization) = Enabled then
            if Node.Kind = Libadalang.Common.Ada_Object_Decl
              and then Libadalang.Analysis.Is_Null
                (Node.As_Object_Decl.F_Default_Expr)
            then
               Report_Rule_Violation
                 (Unit, Node, Complete_Initialization,
                  "object has no explicit initializer");
            elsif Node.Kind = Libadalang.Common.Ada_Component_Decl
              and then Libadalang.Analysis.Is_Null
                (Node.As_Component_Decl.F_Default_Expr)
            then
               Report_Rule_Violation
                 (Unit, Node, Complete_Initialization,
                  "record component has no explicit default");
            end if;
         end if;
         if Rule_States (Volatile_Atomic_Consistency) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Aspect_Assoc
           and then Normalize_Rule_Name
             (Node_Text (Node.As_Aspect_Assoc.F_Id)) = "volatile"
         then
            declare
               Aspects : constant String := Ada.Characters.Handling.To_Lower
                 (Node_Text (Node.Parent));
            begin
               if Ada.Strings.Fixed.Index (Aspects, "atomic") = 0
                 and then Ada.Strings.Fixed.Index
                   (Aspects, "volatile_full_access") = 0
               then
                  Report_Rule_Violation
                    (Unit, Node, Volatile_Atomic_Consistency,
                     "volatile declaration has no atomic/full-access policy");
               end if;
            end;
         end if;
         if Rule_States (Representation_Clause_Policy) = Enabled
           and then Node.Kind in
             Libadalang.Common.Ada_Attribute_Def_Clause
               | Libadalang.Common.Ada_Record_Rep_Clause
         then
            Report_Rule_Violation
              (Unit, Node, Representation_Clause_Policy,
               "explicit representation clause requires consistency review");
         end if;
         if Rule_States (Library_Level_Initialization) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_Object_Decl
           and then Is_Library_Level (Node)
           and then not Libadalang.Analysis.Is_Null
             (Node.As_Object_Decl.F_Default_Expr)
           and then Contains_Call (Node.As_Object_Decl.F_Default_Expr)
         then
            Report_Rule_Violation
              (Unit, Node, Library_Level_Initialization,
               "library-level initializer contains a call");
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
         if Rule_States (Duplicate_With_Clause) = Enabled
           and then Node.Kind = Libadalang.Common.Ada_With_Clause
         then
            declare
               Clause  : constant Libadalang.Analysis.With_Clause :=
                 Node.As_With_Clause;
               Sibling : Libadalang.Analysis.Ada_Node :=
                 Node.Previous_Sibling;
               Found   : Boolean := False;
            begin
               Earlier_Siblings :
               while not Libadalang.Analysis.Is_Null (Sibling) loop
                  if Sibling.Kind = Libadalang.Common.Ada_With_Clause then
                     for Pkg_Name of Clause.F_Packages loop
                        for Earlier_Name of
                          Sibling.As_With_Clause.F_Packages
                        loop
                           if Canonical_Text (Pkg_Name) /= ""
                             and then Canonical_Text (Pkg_Name) =
                               Canonical_Text (Earlier_Name)
                           then
                              Found := True;
                           end if;
                        end loop;
                     end loop;
                  end if;
                  exit Earlier_Siblings when Found;
                  Sibling := Sibling.Previous_Sibling;
               end loop Earlier_Siblings;

               if Found then
                  Report_Rule_Violation
                    (Unit, Node, Duplicate_With_Clause,
                     "with clause names a unit already with'd in this " &
                     "context clause");
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
         if Rule_States (No_Unchecked_Deallocation) = Enabled
           and then Node.Kind =
             Libadalang.Common.Ada_Generic_Subp_Instantiation
         then
            declare
               Generic_Name : constant Libadalang.Analysis.Name :=
                 Node.As_Generic_Subp_Instantiation.F_Generic_Subp_Name;
            begin
               if Is_Ada_Unchecked_Deallocation (Generic_Name) then
                  Report_Rule_Violation
                    (Unit, Node, No_Unchecked_Deallocation,
                     "Ada.Unchecked_Deallocation instantiated");
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
            Log_Verbose_Once
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
