--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;    use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Data_Flow;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Domain; use Adalang_Analyzer.Flow_Domain;
with Adalang_Analyzer.Flow_Eval;   use Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Report;      use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;       use Adalang_Analyzer.Rules;

package body Adalang_Analyzer.Checks.Control_Flow is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   function Has_Substantive_Statement
     (List : Libadalang.Analysis.Stmt_List) return Boolean is
   begin
      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if Libadalang.Analysis.Is_Null (Stmt)
              or else Stmt.Kind = Libadalang.Common.Ada_Pragma_Node
              or else Stmt.Kind = Libadalang.Common.Ada_Null_Stmt
            then
               null;  --  adalang-analyzer: ignore Null_Statement
            else
               return True;
            end if;
         end;
      end loop;

      return False;
   end Has_Substantive_Statement;

   --  True when Node's subtree contains a statement that can end this
   --  loop: exit, return, or raise. A nested loop is not descended into,
   --  since its own exit/return/raise terminates that inner loop, not the
   --  outer one being checked by Analyze_Infinite_Loop.
   function Has_Loop_Termination
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Exit_Stmt
            | Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt
            | Libadalang.Common.Ada_Raise_Stmt =>
            return True;

         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt =>
            --  A transfer inside a nested loop does not terminate this loop.
            return False;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         if Has_Loop_Termination (Node.Child (I)) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Loop_Termination;

   --  Reports Unreachable_Branch for Node, tolerating a null Node so
   --  callers can pass an absent else-part without a guard at each call
   --  site.
   procedure Report_Unreachable_Branch
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class;
      Message : String) is
   begin
      if Rule_States (Unreachable_Branch) = Enabled
        and then not Libadalang.Analysis.Is_Null (Node)
      then
         Report_Rule_Violation (Unit, Node, Unreachable_Branch, Message);
      end if;
   end Report_Unreachable_Branch;

   --  Reports Duplicate_Condition for Cond.
   procedure Report_Duplicate_Condition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Cond : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Rule_States (Duplicate_Condition) = Enabled then
         Report_Rule_Violation
           (Unit, Cond, Duplicate_Condition,
            "condition duplicates an earlier condition in this chain");
      end if;
   end Report_Duplicate_Condition;

   --  Reports Identical_Branches when an if/elsif/else statement chain has
   --  two textually identical bodies immediately adjacent to each other
   --  (then-vs-first-elsif, elsif-vs-elsif, or last-elsif-vs-else).
   procedure Report_Identical_Statement_Branches
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.If_Stmt)
   is
      Previous : Unbounded_String :=
        To_Unbounded_String (Canonical_Text (Stmt.F_Then_Stmts));
   begin
      if Rule_States (Identical_Branches) /= Enabled then
         return;
      end if;

      for Alt of Stmt.F_Alternatives loop
         declare
            Current : constant String := Canonical_Text (Alt.F_Stmts);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Alt.F_Stmts, Identical_Branches,
                  "branch body is identical to the preceding branch");
            end if;
            Previous := To_Unbounded_String (Current);
         end;
      end loop;

      if not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
         declare
            Else_Stmts : constant Libadalang.Analysis.Stmt_List :=
              Stmt.F_Else_Part.F_Stmts;
            Current : constant String := Canonical_Text (Else_Stmts);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Else_Stmts, Identical_Branches,
                  "else body is identical to the preceding branch");
            end if;
         end;
      end if;
   end Report_Identical_Statement_Branches;

   --  The if-expression counterpart of Report_Identical_Statement_Branches.
   procedure Report_Identical_Expression_Branches
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.If_Expr)
   is
      Previous : Unbounded_String :=
        To_Unbounded_String (Canonical_Text (Expr.F_Then_Expr));
   begin
      if Rule_States (Identical_Branches) /= Enabled then
         return;
      end if;

      for Alt of Expr.F_Alternatives loop
         declare
            Current : constant String := Canonical_Text (Alt.F_Then_Expr);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Alt.F_Then_Expr, Identical_Branches,
                  "conditional expression is identical to the preceding one");
            end if;
            Previous := To_Unbounded_String (Current);
         end;
      end loop;

      if not Libadalang.Analysis.Is_Null (Expr.F_Else_Expr) then
         declare
            Current : constant String := Canonical_Text (Expr.F_Else_Expr);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Expr.F_Else_Expr, Identical_Branches,
                  "else expression is identical to the preceding expression");
            end if;
         end;
      end if;
   end Report_Identical_Expression_Branches;

   --  Dead-store reasoning is valid only for an object declared inside the
   --  same subprogram. Package-level and procedure-level state may be read by
   --  callers or by other subprograms after the current body returns.
   function Is_Local_To_Subprogram
     (Decl       : Libadalang.Analysis.Basic_Decl;
      Subprogram : Libadalang.Analysis.Subp_Body) return Boolean
   is
      Ancestor : Libadalang.Analysis.Ada_Node := Decl.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         if Ancestor.Kind = Libadalang.Common.Ada_Subp_Body then
            return Ancestor = Libadalang.Analysis.Ada_Node (Subprogram);
         end if;
         Ancestor := Ancestor.Parent;
      end loop;
      return False;
   end Is_Local_To_Subprogram;

   procedure Analyze_Statement_List  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      List : Libadalang.Analysis.Ada_Node'Class)
   is
      Previous_Terminates : Boolean := False;
      Previous_Assignment : Unbounded_String;
   begin
      if Rule_States (Unreachable_Code) /= Enabled
        and then Rule_States (Repeated_Statement) /= Enabled
        and then Rule_States (Overwritten_Assignment) /= Enabled
      then
         return;
      end if;

      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Stmt) then
               if Previous_Terminates
                 and then Stmt.Kind = Libadalang.Common.Ada_Label
               then
                  --  A label is a possible entry point, so statements from
                  --  this point onward are reachable again.
                  Previous_Terminates := False;  --  adalang-analyzer: ignore Dead_Store
               elsif Previous_Terminates
                 and then Stmt.Kind in Libadalang.Common.Ada_Stmt
               then
                  Report_Rule_Violation
                    (Unit, Stmt, Unreachable_Code,
                     "statement is unreachable");
               end if;

               if Rule_States (Repeated_Statement) = Enabled
                 and then Stmt.Kind = Libadalang.Common.Ada_Assign_Stmt
               then
                  declare
                     Current : constant String := Canonical_Text (Stmt);
                  begin
                     if Current /= ""
                       and then Current = To_String (Previous_Assignment)
                     then
                        Report_Rule_Violation
                          (Unit, Stmt, Repeated_Statement,
                           "assignment duplicates the preceding assignment");
                     end if;
                     Previous_Assignment := To_Unbounded_String (Current);
                  end;
               else
                  Previous_Assignment := Null_Unbounded_String;
               end if;

               if Rule_States (Overwritten_Assignment) = Enabled
                 and then Stmt.Kind = Libadalang.Common.Ada_Assign_Stmt
               then
                  declare
                     Assignment : constant Libadalang.Analysis.Assign_Stmt :=
                       Stmt.As_Assign_Stmt;
                     Decl : constant Libadalang.Analysis.Basic_Decl :=
                       Data_Flow.Assigned_Declaration (Stmt);
                     Target_Text : constant String :=
                       Canonical_Text (Assignment.F_Dest);
                     Is_Self_Assignment : constant Boolean :=
                       Target_Text /= ""
                       and then Target_Text =
                         Canonical_Text (Assignment.F_Expr);
                  begin
                     --  A self-assignment does not establish a distinct new
                     --  value, and Self_Assignment already diagnoses it more
                     --  precisely.  Do not treat the next real write as also
                     --  overwriting the no-op assignment.
                     if Data_Flow.Is_Trackable_Assignment (Stmt)
                       and then not Libadalang.Analysis.Is_Null (Decl)
                       and then not Is_Self_Assignment
                     then
                        for J in I + 1 .. List.Children_Count loop
                           declare
                              Later : constant Libadalang.Analysis.Ada_Node :=
                                List.Child (J);
                           begin
                              if Data_Flow.Reads_Assigned_Target
                                (Later, Assignment)
                              then
                                 exit;  --  adalang-analyzer: ignore No_Exit
                              elsif Data_Flow.Same_Assigned_Target
                                (Stmt, Later)
                              then
                                 Report_Rule_Violation
                                   (Unit, Stmt, Overwritten_Assignment,
                                    "assigned value is overwritten before " &
                                      "it is read");
                                 exit;  --  adalang-analyzer: ignore No_Exit
                              end if;
                           end;
                        end loop;
                     end if;
                  end;
               end if;

               if Terminates_Statement (Stmt) then
                  Previous_Terminates := True;  --  adalang-analyzer: ignore Dead_Store
               end if;
            end if;
         end;
      end loop;
   end Analyze_Statement_List;

   procedure Analyze_Assignment  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Assign_Stmt)
   is
      Target_Text : constant String := Canonical_Text (Stmt.F_Dest);
      Value_Text  : constant String := Canonical_Text (Stmt.F_Expr);
   begin
      if Rule_States (Self_Assignment) = Enabled
        and then Target_Text /= ""
        and then
          (Target_Text = Value_Text
           or else
             (Stmt.F_Dest.Kind = Libadalang.Common.Ada_Identifier
              and then Stmt.F_Expr.Kind = Libadalang.Common.Ada_Identifier
              and then not Libadalang.Analysis.Is_Null
                (Data_Flow.Assigned_Declaration (Stmt))
              and then Data_Flow.Assigned_Declaration (Stmt) =
                Data_Flow.Referenced_Declaration (Stmt.F_Expr)))
      then
         Report_Rule_Violation
           (Unit, Stmt, Self_Assignment,
            "assignment stores an expression back into itself");
      end if;

      if Rule_States (Dead_Store) = Enabled
        and then Data_Flow.Is_Trackable_Assignment (Stmt)
      then
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Data_Flow.Assigned_Declaration (Stmt);
            Subprogram : constant Libadalang.Analysis.Subp_Body :=
              Data_Flow.Enclosing_Subprogram (Stmt);
         begin
            if not Libadalang.Analysis.Is_Null (Decl)
              and then Decl.Kind = Libadalang.Common.Ada_Object_Decl
              and then not Libadalang.Analysis.Is_Null (Subprogram)
              and then Is_Local_To_Subprogram (Decl, Subprogram)
              and then not Data_Flow.Has_Read_After
                (Subprogram.F_Stmts, Decl, Stmt)
            then
               Report_Rule_Violation
                 (Unit, Stmt, Dead_Store,
                  "assigned value is never read later in this subprogram");
            end if;
         end;
      end if;

      if Rule_States (Function_Side_Effect) = Enabled
        and then Stmt.F_Dest.Kind = Libadalang.Common.Ada_Identifier
      then
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Data_Flow.Assigned_Declaration (Stmt);
            Subprogram : constant Libadalang.Analysis.Subp_Body :=
              Data_Flow.Enclosing_Subprogram (Stmt);
         begin
            if not Libadalang.Analysis.Is_Null (Decl)
              and then not Libadalang.Analysis.Is_Null (Subprogram)
              and then not Libadalang.Analysis.Is_Null (Subprogram.F_Subp_Spec)
              and then not Libadalang.Analysis.Is_Null
                (Subprogram.F_Subp_Spec.F_Subp_Kind)
              and then Subprogram.F_Subp_Spec.F_Subp_Kind.Kind =
                Libadalang.Common.Ada_Subp_Kind_Function
              and then not Is_Local_To_Subprogram (Decl, Subprogram)
            then
               Report_Rule_Violation
                 (Unit, Stmt, Function_Side_Effect,
                  "function assigns to state outside its own parameters " &
                    "and local variables");
            end if;
         end;
      end if;
   end Analyze_Assignment;

   procedure Analyze_Call_Statement
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Call_Stmt)
   is
      Call : constant Libadalang.Analysis.Name := Stmt.F_Call;
   begin
      if Rule_States (Dead_Store) /= Enabled
        or else Call.Kind /= Libadalang.Common.Ada_Call_Expr
      then
         return;
      end if;

      declare
         Suffix : constant Libadalang.Analysis.Ada_Node :=
           Call.As_Call_Expr.F_Suffix;
      begin
         for Index in 1 .. Suffix.Children_Count loop
            declare
               Child : constant Libadalang.Analysis.Ada_Node :=
                 Suffix.Child (Index);
            begin
               if Child.Kind = Libadalang.Common.Ada_Param_Assoc then
                  declare
                     Assoc  : constant Libadalang.Analysis.Param_Assoc :=
                       Child.As_Param_Assoc;
                     Actual : constant Libadalang.Analysis.Expr :=
                       Assoc.F_R_Expr;
                     Is_Out_Only : Boolean := False;
                     Is_In_Out   : Boolean := False;
                  begin
                     for Formal_Name of
                       Assoc.P_Get_Params (Imprecise_Fallback => True)
                     loop
                        declare
                           Ancestor : Libadalang.Analysis.Ada_Node :=
                             Formal_Name.Parent;
                        begin
                           while not Libadalang.Analysis.Is_Null (Ancestor)
                             and then Ancestor.Kind not in
                               Libadalang.Common.Ada_Param_Spec_Range
                           loop
                              Ancestor := Ancestor.Parent;
                           end loop;

                           if not Libadalang.Analysis.Is_Null (Ancestor) then
                              if Ancestor.As_Param_Spec.F_Mode.Kind in
                                Libadalang.Common.Ada_Mode_In_Out_Range
                              then
                                 Is_In_Out := True;
                              elsif Ancestor.As_Param_Spec.F_Mode.Kind in
                                Libadalang.Common.Ada_Mode_Out_Range
                              then
                                 Is_Out_Only := True;
                              end if;
                           end if;
                        end;
                     end loop;

                     --  An in out actual consumes its incoming value at the
                     --  call boundary. Do not reduce that read/write contract
                     --  to a pure output dead store; pure out actuals remain
                     --  eligible for the existing result-not-read diagnostic.
                     if Is_Out_Only and then not Is_In_Out
                       and then Actual.Kind =
                         Libadalang.Common.Ada_Identifier
                     then
                        declare
                           Decl : constant Libadalang.Analysis.Basic_Decl :=
                             Data_Flow.Referenced_Declaration (Actual);
                           Subprogram : constant
                             Libadalang.Analysis.Subp_Body :=
                               Data_Flow.Enclosing_Subprogram (Stmt);
                        begin
                           if not Libadalang.Analysis.Is_Null (Decl)
                             and then Decl.Kind in
                               Libadalang.Common.Ada_Object_Decl_Range
                             and then not Libadalang.Analysis.Is_Null
                               (Subprogram)
                             and then Is_Local_To_Subprogram
                               (Decl, Subprogram)
                             and then not Data_Flow.Has_Read_After_Node
                               (Subprogram.F_Stmts, Decl, Stmt)
                           then
                              Report_Rule_Violation
                                (Unit, Actual, Dead_Store,
                                 "output value assigned by call is never " &
                                   "read later in this subprogram");
                           end if;
                        end;
                     end if;
                  exception
                     when others =>
                        --  An unresolved call profile is conservatively
                        --  skipped.
                        null;  --  adalang-analyzer: ignore Null_Statement
                  end;
               end if;
            end;
         end loop;
      end;
   end Analyze_Call_Statement;

   procedure Analyze_Case_Statement  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Case_Stmt)
   is
      Alternatives : constant Libadalang.Analysis.Case_Stmt_Alternative_List :=
        Stmt.F_Alternatives;
   begin
      if Rule_States (Unreachable_Case_Alternative) /= Enabled
        and then Rule_States (Overlapping_Case_Ranges) /= Enabled
      then
         return;
      end if;

      for Current_Index in 1 .. Alternatives.Children_Count loop
         declare
            Current_Alt : constant Libadalang.Analysis.Case_Stmt_Alternative :=
              Alternatives.Child (Current_Index).As_Case_Stmt_Alternative;
         begin
            for Current_Choice of Current_Alt.F_Choices loop
               declare
                  Current_Range : constant Static_Interval :=
                    Choice_Interval (Current_Choice);
                  Is_Overlapping : Boolean := False;
                  Is_Unreachable : Boolean := False;
               begin
                  for Prior_Index in 1 .. Current_Index - 1 loop
                     declare
                        Prior_Alt : constant
                          Libadalang.Analysis.Case_Stmt_Alternative :=
                            Alternatives.Child (Prior_Index)
                              .As_Case_Stmt_Alternative;
                     begin
                        for Prior_Choice of Prior_Alt.F_Choices loop
                           declare
                              Prior_Range : constant Static_Interval :=
                                Choice_Interval (Prior_Choice);
                              Same_Choice : constant Boolean :=
                                Canonical_Text (Current_Choice) /= ""
                                and then Canonical_Text (Current_Choice) =
                                  Canonical_Text (Prior_Choice);
                           begin
                              if Prior_Choice.Kind =
                                Libadalang.Common.Ada_Others_Designator
                              then
                                 Is_Unreachable := True;
                              elsif Same_Choice then
                                 Is_Overlapping := True;
                                 Is_Unreachable := True;
                              elsif Current_Range.Known
                                and then Prior_Range.Known
                                and then Current_Range.Low <= Prior_Range.High
                                and then Prior_Range.Low <= Current_Range.High
                              then
                                 Is_Overlapping := True;
                                 if Current_Range.Low >= Prior_Range.Low
                                   and then Current_Range.High <= Prior_Range.High
                                 then
                                    Is_Unreachable := True;
                                 end if;
                              end if;
                           end;
                        end loop;
                     end;
                  end loop;

                  if Is_Overlapping
                    and then Rule_States (Overlapping_Case_Ranges) = Enabled
                  then
                     Report_Rule_Violation
                       (Unit, Current_Choice, Overlapping_Case_Ranges,
                        "case choice overlaps an earlier alternative");
                  end if;
                  if Is_Unreachable
                    and then Rule_States (Unreachable_Case_Alternative) = Enabled
                  then
                     Report_Rule_Violation
                       (Unit, Current_Choice, Unreachable_Case_Alternative,
                        "case choice is covered by an earlier alternative");
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Analyze_Case_Statement;

   procedure Analyze_Infinite_Loop
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Loop_Node : Libadalang.Analysis.Base_Loop_Stmt)
   is
      Is_Unconditional : Boolean :=
        Loop_Node.Kind = Libadalang.Common.Ada_Loop_Stmt;
   begin
      if Loop_Node.Kind = Libadalang.Common.Ada_While_Loop_Stmt then
         declare
            Spec : constant Libadalang.Analysis.Loop_Spec :=
              Loop_Node.As_While_Loop_Stmt.F_Spec;
         begin
            Is_Unconditional := not Libadalang.Analysis.Is_Null (Spec)
              and then Boolean_Value (Spec.As_While_Loop_Spec.F_Expr) =
                Bool_True;
         end;
      end if;

      if Rule_States (Infinite_Loop) = Enabled
        and then Is_Unconditional
        and then not Has_Loop_Termination (Loop_Node.F_Stmts)
      then
         Report_Rule_Violation
           (Unit, Loop_Node, Infinite_Loop,
            "unconditional loop has no explicit termination path");
      end if;
   end Analyze_Infinite_Loop;

   procedure Analyze_If_Statement  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.If_Stmt)
   is
      First_Cond          : constant Libadalang.Analysis.Expr :=
        Stmt.F_Cond_Expr;
      First_Text          : constant String := Canonical_Text (First_Cond);
      First_Value         : constant Abstract_Bool :=
        Boolean_Value (First_Cond);
      Alternatives        : constant Libadalang.Analysis.Elsif_Stmt_Part_List :=
        Stmt.F_Alternatives;
      Previous_Always_True : Boolean := First_Value = Bool_True;
   begin
      if First_Value = Bool_False then
         Report_Unreachable_Branch
           (Unit, Stmt.F_Then_Stmts,
            "then branch is unreachable because its condition is always false");
      end if;

      for I in 1 .. Alternatives.Children_Count loop
         declare
            Alt_Node : constant Libadalang.Analysis.Ada_Node :=
              Alternatives.Child (I);
            Alt      : constant Libadalang.Analysis.Elsif_Stmt_Part :=
              Alt_Node.As_Elsif_Stmt_Part;
            Cond     : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
            Cond_Text : constant String := Canonical_Text (Cond);
            Value    : constant Abstract_Bool := Boolean_Value (Cond);
         begin
            if Cond_Text /= "" and then Cond_Text = First_Text then
               Report_Duplicate_Condition (Unit, Cond);
            else
               for J in 1 .. I - 1 loop
                  declare
                     Previous : constant Libadalang.Analysis.Ada_Node :=
                       Alternatives.Child (J);
                  begin
                     if Cond_Text /= ""
                       and then Cond_Text =
                         Canonical_Text
                           (Previous.As_Elsif_Stmt_Part.F_Cond_Expr)
                     then
                        Report_Duplicate_Condition (Unit, Cond);
                        exit;  --  adalang-analyzer: ignore No_Exit
                     end if;
                  end;
               end loop;
            end if;

            if Previous_Always_True then
               Report_Unreachable_Branch
                 (Unit, Alt,
                  "elsif branch is unreachable because an earlier condition "
                  & "is always true");
            elsif Value = Bool_False then
               Report_Unreachable_Branch
                 (Unit, Alt.F_Stmts,
                  "elsif branch is unreachable because its condition is "
                  & "always false");
            elsif Value = Bool_True then
               Previous_Always_True := True;  --  adalang-analyzer: ignore Dead_Store
            end if;
         end;
      end loop;

      if Previous_Always_True
        and then not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
      then
         Report_Unreachable_Branch
           (Unit, Stmt.F_Else_Part,
            "else branch is unreachable because an earlier condition is "
           & "always true");
      end if;

      if Rule_States (Empty_If_Body) = Enabled
        and then Alternatives.Children_Count = 0
        and then Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
        and then not Has_Substantive_Statement (Stmt.F_Then_Stmts)
      then
         Report_Rule_Violation
           (Unit, Stmt, Empty_If_Body,
            "if statement has no effect because its body is empty");
      end if;

      if Rule_States (Unnecessary_Else_After_Return) = Enabled
        and then Alternatives.Children_Count = 0
        and then not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
        and then Stmt.F_Then_Stmts.Children_Count > 0
        and then Terminates_Statement
          (Stmt.F_Then_Stmts.Child (Stmt.F_Then_Stmts.Children_Count))
      then
         Report_Rule_Violation
           (Unit, Stmt.F_Else_Part, Unnecessary_Else_After_Return,
            "else is unnecessary because the then branch always returns, " &
              "raises, or exits");
      end if;

      Report_Identical_Statement_Branches (Unit, Stmt);
   end Analyze_If_Statement;

   procedure Analyze_If_Expression  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.If_Expr)
   is
      First_Cond          : constant Libadalang.Analysis.Expr :=
        Expr.F_Cond_Expr;
      First_Text          : constant String := Canonical_Text (First_Cond);
      First_Value         : constant Abstract_Bool :=
        Boolean_Value (First_Cond);
      Alternatives        : constant Libadalang.Analysis.Elsif_Expr_Part_List :=
        Expr.F_Alternatives;
      Previous_Always_True : Boolean := First_Value = Bool_True;
   begin
      if First_Value = Bool_False then
         Report_Unreachable_Branch
           (Unit, Expr.F_Then_Expr,
            "then expression is unreachable because its condition is always "
            & "false");
      end if;

      for I in 1 .. Alternatives.Children_Count loop
         declare
            Alt_Node : constant Libadalang.Analysis.Ada_Node :=
              Alternatives.Child (I);
            Alt      : constant Libadalang.Analysis.Elsif_Expr_Part :=
              Alt_Node.As_Elsif_Expr_Part;
            Cond     : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
            Cond_Text : constant String := Canonical_Text (Cond);
            Value    : constant Abstract_Bool := Boolean_Value (Cond);
         begin
            if Cond_Text /= "" and then Cond_Text = First_Text then
               Report_Duplicate_Condition (Unit, Cond);
            else
               for J in 1 .. I - 1 loop
                  declare
                     Previous : constant Libadalang.Analysis.Ada_Node :=
                       Alternatives.Child (J);
                  begin
                     if Cond_Text /= ""
                       and then Cond_Text =
                         Canonical_Text
                           (Previous.As_Elsif_Expr_Part.F_Cond_Expr)
                     then
                        Report_Duplicate_Condition (Unit, Cond);
                        exit;  --  adalang-analyzer: ignore No_Exit
                     end if;
                  end;
               end loop;
            end if;

            if Previous_Always_True then
               Report_Unreachable_Branch
                 (Unit, Alt,
                  "elsif expression is unreachable because an earlier "
                  & "condition is always true");
            elsif Value = Bool_False then
               Report_Unreachable_Branch
                 (Unit, Alt.F_Then_Expr,
                  "elsif expression is unreachable because its condition is "
                  & "always false");
            elsif Value = Bool_True then
               Previous_Always_True := True;  --  adalang-analyzer: ignore Dead_Store
            end if;
         end;
      end loop;

      if Previous_Always_True
        and then not Libadalang.Analysis.Is_Null (Expr.F_Else_Expr)
      then
         Report_Unreachable_Branch
           (Unit, Expr.F_Else_Expr,
            "else expression is unreachable because an earlier condition is "
            & "always true");
      end if;

      Report_Identical_Expression_Branches (Unit, Expr);
   end Analyze_If_Expression;

   procedure Analyze_Exception_Handler
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Handler : Libadalang.Analysis.Exception_Handler) is
   begin
      if Rule_States (Empty_Exception_Handler) = Enabled
        and then not Has_Substantive_Statement (Handler.F_Stmts)
      then
         Report_Rule_Violation
           (Unit, Handler, Empty_Exception_Handler,
            "exception handler contains no substantive statements");
      end if;

      if Rule_States (Exception_Swallowed) = Enabled then
         declare
            Handles_Others : Boolean := False;
         begin
            for Choice of Handler.F_Handled_Exceptions loop
               if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
                  Handles_Others := True;  --  adalang-analyzer: ignore Dead_Store
               end if;
            end loop;

            if Handles_Others
              and then not Has_Substantive_Statement (Handler.F_Stmts)
            then
               Report_Rule_Violation
                 (Unit, Handler, Exception_Swallowed,
                  "when others handler silently discards the exception");
            end if;
         end;
      end if;
   end Analyze_Exception_Handler;

end Adalang_Analyzer.Checks.Control_Flow;
