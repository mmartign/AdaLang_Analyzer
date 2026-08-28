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

with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Text;
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
   use type Adalang_Analyzer.Checks.Data_Flow.Access_Kind;

   function Has_Substantive_Statement
     (List : Libadalang.Analysis.Stmt_List) return Boolean is
   begin
      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if Libadalang.Analysis.Is_Null (Stmt)  --  adalang-analyzer: ignore Empty_Then_Body
              or else Stmt.Kind = Libadalang.Common.Ada_Null_Stmt
            then
               null;  --  adalang-analyzer: ignore Null_Statement
            elsif Stmt.Kind = Libadalang.Common.Ada_Pragma_Node then

               --  Most pragmas (Unreferenced, Warnings, Import, Inline,
               --  ...) are purely declarative/informational and genuinely
               --  leave a branch with no effect; pragma Assert is not one
               --  of them -- "else pragma Assert (False); end if;" is a
               --  deliberate "this must never happen" guard, not filler.
               --  Found on real code, not just by inspection: a false
               --  Empty_Else_Body on exactly this shape
               --  (AdaCore/Ada_Drivers_Library,
               --  stm32-dma2d-interrupt.adb's Interrupt) while running
               --  this project's own GNATcheck oracle comparison.
               if Canonical_Text (Stmt.As_Pragma_Node.F_Id) = "assert" then
                  return True;
               end if;
            else
               return True;
            end if;
         end;
      end loop;

      return False;
   end Has_Substantive_Statement;

   --  True when Node's subtree contains a statement that can end the loop
   --  under analysis: exit, return, or raise. A bare "exit" only counts
   --  while Exit_Terminates is True; once the scan has stepped inside a
   --  nested loop, an "exit" found there only terminates that inner loop
   --  (not the outer one Analyze_Infinite_Loop is checking), so the
   --  recursive descent into a nested loop's own subtree continues with
   --  Exit_Terminates set to False. "return"/"raise" unwind past every
   --  enclosing loop regardless of nesting depth, so they always count.
   --  A labeled "exit <Outer_Name>;" naming the loop under analysis from
   --  inside a nested loop is not specially recognized and is treated the
   --  same as a bare exit, a narrow, documented conservative gap rather
   --  than a soundness issue: it can only under-report a termination path,
   --  never claim one that isn't there.
   function Has_Loop_Termination
     (Node            : Libadalang.Analysis.Ada_Node'Class;
      Exit_Terminates : Boolean := True) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Exit_Stmt =>
            return Exit_Terminates;

         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt
            | Libadalang.Common.Ada_Raise_Stmt =>
            return True;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      declare
         Next_Exit_Terminates : constant Boolean :=
           Exit_Terminates
           and then Node.Kind not in
             Libadalang.Common.Ada_For_Loop_Stmt
             | Libadalang.Common.Ada_Loop_Stmt
             | Libadalang.Common.Ada_While_Loop_Stmt;
      begin
         for I in 1 .. Node.Children_Count loop
            if Has_Loop_Termination (Node.Child (I), Next_Exit_Terminates) then
               return True;
            end if;
         end loop;
      end;

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

   --  Reports Identical_Case_Alternative when two adjacent case alternatives
   --  have textually identical bodies. Adjacent-only, matching
   --  Report_Identical_Statement_Branches's if/elsif comparison.
   procedure Report_Identical_Case_Alternatives
     (Unit         : Libadalang.Analysis.Analysis_Unit;
      Alternatives : Libadalang.Analysis.Case_Stmt_Alternative_List)
   is
      Previous : Unbounded_String;
      Has_Previous : Boolean := False;
   begin
      if Rule_States (Identical_Case_Alternative) /= Enabled then
         return;
      end if;

      for Alt of Alternatives loop
         declare
            Current : constant String := Canonical_Text (Alt.F_Stmts);
         begin
            if Has_Previous
              and then Current /= ""
              and then Current = To_String (Previous)
            then
               Report_Rule_Violation
                 (Unit, Alt.F_Stmts, Identical_Case_Alternative,
                  "case alternative body is identical to the preceding " &
                    "alternative");
            end if;
            Previous := To_Unbounded_String (Current);
            Has_Previous := True;
         end;
      end loop;
   end Report_Identical_Case_Alternatives;

   --  Reports Null_Case_Alternative when a case alternative's body has no
   --  substantive statement (only null statements and/or pragmas), so the
   --  alternative has no effect. The case-statement counterpart of
   --  Empty_If_Body, which is deliberately scoped to plain if statements
   --  and does not see case alternatives. Deliberately does not flag a
   --  catch-all "when others => null;": that is a common, intentional Ada
   --  idiom for "every other choice needs no handling here" (confirmed by
   --  this analyzer's own source, which uses that exact idiom throughout
   --  its own Ada_Node_Kind_Type dispatch code) -- unlike an empty
   --  alternative naming a specific choice, which usually signals a
   --  forgotten implementation.
   procedure Report_Null_Case_Alternatives
     (Unit         : Libadalang.Analysis.Analysis_Unit;
      Alternatives : Libadalang.Analysis.Case_Stmt_Alternative_List)
   is
   begin
      if Rule_States (Null_Case_Alternative) /= Enabled then
         return;
      end if;

      for Alt of Alternatives loop
         if not Has_Substantive_Statement (Alt.F_Stmts)
           and then Alt.F_Choices.Children_Count > 0
           and then Alt.F_Choices.Child (1).Kind /=
             Libadalang.Common.Ada_Others_Designator
         then
            Report_Rule_Violation
              (Unit, Alt, Null_Case_Alternative,
               "case alternative has no effect because its body is empty");
         end if;
      end loop;
   end Report_Null_Case_Alternatives;

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

   --  Whether Decl -- already known to be an Ada_Object_Decl local to
   --  Subprogram, as Is_Local_To_Subprogram itself establishes before a
   --  caller reaches this check -- is actually tracking meaningfully local
   --  storage, as opposed to being a renaming of part of a longer-lived
   --  object (a parameter's or global's field, element, or dereferenced
   --  part). Is_Local_To_Subprogram is a purely lexical-scope test: a
   --  renaming declaration is "local" by that test even when what it
   --  renames is not, because the declaration itself is textually nested
   --  inside Subprogram regardless of what it aliases. Observed in the
   --  wild: AWS.HTTP2.Stream's "Info : Error_Details renames Self.
   --  Error_Detail;", where Self is an in-out parameter -- a write to Info
   --  is really a write to Self.Error_Detail, observable by the caller
   --  after return and by any other code that later reads Self.
   --  Error_Detail directly, never a locally dead store, yet Dead_Store's
   --  own write-tracking (Data_Flow.Assigned_Declaration) resolves a bare
   --  "Info := ...;" to Info's own renaming declaration rather than
   --  Self's, because Data_Flow.Ultimate_Object only follows a renamed
   --  object that is itself a bare identifier ("Y renames X;"), not one
   --  reached through a selected component, indexed component, or
   --  dereference. Walks the same shapes here, coarsely, the same
   --  "whichever depth of nesting, only the base object matters" treatment
   --  already used elsewhere in this project (e.g. Same_Parameter): a
   --  renaming of a bare local variable ("Y renames X;" where X is itself
   --  local to Subprogram) is unaffected, since only a renamed object that
   --  walks down to something NOT local to Subprogram disqualifies Decl.
   function Renames_Nonlocal_Object
     (Decl       : Libadalang.Analysis.Basic_Decl;
      Subprogram : Libadalang.Analysis.Subp_Body) return Boolean
   is
   begin
      if Decl.Kind /= Libadalang.Common.Ada_Object_Decl then
         return False;
      end if;

      declare
         Clause : constant Libadalang.Analysis.Renaming_Clause :=
           Decl.As_Object_Decl.F_Renaming_Clause;
      begin
         if Libadalang.Analysis.Is_Null (Clause) then
            return False;
         end if;

         declare
            Current : Libadalang.Analysis.Ada_Node :=
              Libadalang.Analysis.Ada_Node (Clause.F_Renamed_Object);
         begin
            loop
               case Current.Kind is
                  when Libadalang.Common.Ada_Dotted_Name =>
                     Current := Libadalang.Analysis.Ada_Node
                       (Current.As_Dotted_Name.F_Prefix);
                  when Libadalang.Common.Ada_Call_Expr =>
                     Current := Libadalang.Analysis.Ada_Node
                       (Current.As_Call_Expr.F_Name);
                  when Libadalang.Common.Ada_Explicit_Deref =>
                     Current := Libadalang.Analysis.Ada_Node
                       (Current.As_Explicit_Deref.F_Prefix);
                  when others =>
                     exit;
               end case;
            end loop;

            if Current.Kind /= Libadalang.Common.Ada_Identifier then
               --  A shape this coarse walk does not understand (e.g. the
               --  renamed object is itself a function call's result) --
               --  conservatively treat as non-local rather than risk a
               --  false Dead_Store report.
               return True;
            end if;

            declare
               Base : constant Libadalang.Analysis.Basic_Decl :=
                 Current.As_Name.P_Referenced_Decl
                   (Imprecise_Fallback => True);
            begin
               return Libadalang.Analysis.Is_Null (Base)
                 or else Base.Kind /= Libadalang.Common.Ada_Object_Decl
                 or else not Is_Local_To_Subprogram (Base, Subprogram);
            end;
         end;
      end;
   exception
      when others =>
         return True;
   end Renames_Nonlocal_Object;

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
                     Decl    : constant Libadalang.Analysis.Basic_Decl :=
                       Data_Flow.Assigned_Declaration (Stmt);
                  begin
                     if Current /= ""
                       and then Current = To_String (Previous_Assignment)
                       and then (Libadalang.Analysis.Is_Null (Decl)
                                 or else not Data_Flow.Is_Externally_Observable
                                   (Decl))
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
                       and then not Data_Flow.Is_Externally_Observable (Decl)
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

   function Is_Inside_Loop
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         if Ancestor.Kind in Libadalang.Common.Ada_Base_Loop_Stmt then
            return True;
         elsif Ancestor.Kind in Libadalang.Common.Ada_Subp_Body then
            return False;
         end if;
         Ancestor := Ancestor.Parent;
      end loop;
      return False;
   end Is_Inside_Loop;

   function Is_Object_Renaming_Name
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return False;
      end if;

      Decl := Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      return not Libadalang.Analysis.Is_Null (Decl)
        and then Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
        and then not Libadalang.Analysis.Is_Null
          (Decl.As_Object_Decl.F_Renaming_Clause);
   exception
      when others =>
         return False;
   end Is_Object_Renaming_Name;

   --  True when Expr is a '&' concatenation (Libadalang flattens a whole
   --  chain of '&'s into one Concat_Op, regardless of how many operands)
   --  and one of its operands has the same canonical text as Target_Text --
   --  the "S := S & ..." accumulator shape.
   function Is_Self_Referential_Concatenation
     (Expr : Libadalang.Analysis.Expr'Class; Target_Text : String)
      return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind /= Libadalang.Common.Ada_Concat_Op
      then
         return False;
      end if;

      for Operand of Expr.As_Concat_Op.P_Operands loop
         if Canonical_Text (Operand) = Target_Text then
            return True;
         end if;
      end loop;
      return False;
   end Is_Self_Referential_Concatenation;

   --  Whether Stmt's target is declared with a fixed-bounds String-family
   --  type. Reads the assigned declaration's type expression rather than
   --  requiring an exact type match, so String and project-defined string
   --  subtypes (e.g. "Name_String") are recognized. Ada.Strings.Unbounded's
   --  own '&' also reallocates on every call, but its fix is "call Append
   --  instead of '&'", not "switch to Unbounded_String", so an
   --  already-Unbounded_String target is deliberately excluded rather than
   --  given this rule's misleading guidance. Resolution failure is treated
   --  as "not a string" rather than risking a false positive.
   function Target_Is_String_Typed
     (Stmt : Libadalang.Analysis.Assign_Stmt) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Data_Flow.Referenced_Declaration (Stmt.F_Dest);
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return False;
      end if;

      declare
         Type_Text : constant String :=
           Canonical_Text (Decl.P_Type_Expression);
      begin
         return Ada.Strings.Fixed.Index (Type_Text, "string") > 0
           and then Ada.Strings.Fixed.Index (Type_Text, "unbounded") = 0;
      end;
   exception
      when others =>
         return False;
   end Target_Is_String_Typed;

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
                Data_Flow.Referenced_Declaration (Stmt.F_Expr)
              and then
                (Is_Object_Renaming_Name (Stmt.F_Dest)
                 or else Is_Object_Renaming_Name (Stmt.F_Expr))))
      then
         Report_Rule_Violation
           (Unit, Stmt, Self_Assignment,
            "assignment stores an expression back into itself");
      end if;

      if Rule_States (Dead_Store) = Enabled
        and then Data_Flow.Is_Trackable_Assignment (Stmt)
        and then not Is_Inside_Loop (Stmt)
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
              and then not Renames_Nonlocal_Object (Decl, Subprogram)
              and then not Data_Flow.Is_Externally_Observable (Decl)
              and then not Data_Flow.Has_Read_After
                (Subprogram.F_Stmts, Decl, Stmt)
            then
               Report_Rule_Violation
                 (Unit, Stmt, Dead_Store,
                  "assigned value is never read later in this subprogram");
            end if;
         end;
      end if;

      if Rule_States (Inefficient_String_Concatenation) = Enabled
        and then Is_Inside_Loop (Stmt)
        and then Stmt.F_Dest.Kind = Libadalang.Common.Ada_Identifier
        and then Target_Text /= ""
        and then Is_Self_Referential_Concatenation (Stmt.F_Expr, Target_Text)
        and then Target_Is_String_Typed (Stmt)
      then
         Report_Rule_Violation
           (Unit, Stmt, Inefficient_String_Concatenation,
            "string rebuilt with '&' inside a loop; accumulate into an " &
            "Unbounded_String instead");
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

   type Resource_Op is (Not_A_Resource_Call, Opens_Resource, Closes_Resource);

   type Resource_Call is record
      Op   : Resource_Op := Not_A_Resource_Call;
      Decl : Libadalang.Analysis.Basic_Decl := Libadalang.Analysis.No_Basic_Decl;
   end record;

   --  The first Param_Assoc actual expression among Call's suffix
   --  children, or No_Expr. Shared by Classify_Resource_Call (the object
   --  actual of an Open/Create/Close call) and Guards_Is_Open below (the
   --  object actual of an Is_Open call).
   function First_Param_Assoc_Actual
     (Call : Libadalang.Analysis.Call_Expr) return Libadalang.Analysis.Expr
   is
      Suffix : constant Libadalang.Analysis.Ada_Node := Call.F_Suffix;
   begin
      for Index in 1 .. Suffix.Children_Count loop
         declare
            Child : constant Libadalang.Analysis.Ada_Node :=
              Suffix.Child (Index);
         begin
            if Child.Kind = Libadalang.Common.Ada_Param_Assoc then
               return Child.As_Param_Assoc.F_R_Expr;
            end if;
         end;
      end loop;
      return Libadalang.Analysis.No_Expr;
   end First_Param_Assoc_Actual;

   --  Purely syntactic fallback for Instantiation_Generic_Name: when Inst
   --  is a Generic_Package_Instantiation, reads the generic name as
   --  written at the instantiation itself (F_Generic_Pkg_Name) and
   --  accepts it whether spelled fully qualified ("Ada.Direct_IO") or
   --  bare ("Direct_IO", brought into scope by a "use Ada.Direct_IO;"
   --  clause) -- unlike Instantiation_Generic_Name's own primary path,
   --  there is no semantic resolution left to confirm a bare spelling
   --  actually denotes Ada.Direct_IO rather than some unrelated,
   --  identically-named generic also in scope, so this is used only when
   --  that primary path has already failed outright.
   function Instantiation_Written_Generic_Name
     (Inst : Libadalang.Analysis.Basic_Decl'Class) return String
   is
   begin
      if Inst.Kind /= Libadalang.Common.Ada_Generic_Package_Instantiation
      then
         return "";
      end if;

      declare
         Written : constant String := Canonical_Text
           (Inst.As_Generic_Package_Instantiation.F_Generic_Pkg_Name);
      begin
         if Written in "ada.direct_io" | "direct_io" then
            return "ada.direct_io";
         elsif Written in "ada.sequential_io" | "sequential_io" then
            return "ada.sequential_io";
         end if;
         return "";
      end;
   exception
      when others =>
         return "";
   end Instantiation_Written_Generic_Name;

   --  When Inst is a Generic_Package_Instantiation of Ada.Direct_IO or
   --  Ada.Sequential_IO, returns that generic's own as-declared name
   --  ("ada.direct_io"/"ada.sequential_io"); otherwise "". Resolves
   --  Inst's own designated generic decl via P_Designated_Generic_Decl.
   --  That property itself returns an entity view rebound as "the
   --  expanded generic unit at this instantiation" (per its own
   --  documentation), so its P_Canonical_Fully_Qualified_Name is
   --  instantiation-relative and unusable here; reading the plain source
   --  text of its P_Defining_Name instead sidesteps that, since text
   --  extraction is purely positional and unaffected by the entity's
   --  rebindings -- confirmed empirically to read "Ada.Direct_IO"/
   --  "Ada.Sequential_IO" regardless of instantiation shape. Shared by
   --  Instantiated_Resource_Package below (walking up from a resolved
   --  member declaration) and Resolve_Instantiation_Member further down
   --  (resolving the instantiation object itself directly, for FP-062's
   --  bare-generic-name-via-"use" shape, where the member can't be
   --  resolved at all).
   function Instantiation_Generic_Name
     (Inst : Libadalang.Analysis.Basic_Decl'Class) return String
   is
   begin
      if Inst.Kind /= Libadalang.Common.Ada_Generic_Package_Instantiation
      then
         return "";
      end if;

      declare
         Generic_Decl : constant Libadalang.Analysis.Basic_Decl :=
           Libadalang.Analysis.Basic_Decl
             (Inst.As_Generic_Package_Instantiation.P_Designated_Generic_Decl);
      begin
         if Libadalang.Analysis.Is_Null (Generic_Decl) then
            return "";
         end if;

         declare
            Written : constant String :=
              Canonical_Text (Generic_Decl.P_Defining_Name);
         begin
            if Written in "ada.direct_io" | "ada.sequential_io" then
               return Written;
            end if;
            return "";
         end;
      end;
   exception
      when others =>
         --  P_Designated_Generic_Decl itself raises Property_Error
         --  (dereferencing a null access) for a package instantiated via
         --  a bare generic name reached only through a "use" clause on
         --  the generic itself (FP-062's root cause turned out to run
         --  deeper than the member-resolution failure Resolve_
         --  Instantiation_Member was first written to work around: this
         --  same bare-name shape breaks the instantiation's own semantic
         --  properties too, confirmed empirically) -- fall back to the
         --  syntactic name written at the instantiation itself
         --  (F_Generic_Pkg_Name), accepting either the fully qualified
         --  or bare spelling, since no semantic confirmation is possible
         --  here at all.
         return Instantiation_Written_Generic_Name (Inst);
   end Instantiation_Generic_Name;

   --  When Callee (an Open/Create/Close-shaped declaration reached from a
   --  call) was reached through a generic package instantiation of
   --  Ada.Direct_IO or Ada.Sequential_IO, returns that generic's own
   --  as-declared name; otherwise "". Unlike Ada.Text_IO/Ada.Streams.
   --  Stream_IO, Callee.P_Canonical_Fully_Qualified_Name itself is
   --  useless here -- Libadalang resolves an instantiated package's own
   --  nested entities against the instantiation's name (e.g. "my_io.open"
   --  for "package My_IO is new Ada.Sequential_IO (...);"), not the
   --  generic template -- so instead this walks Callee's own
   --  instantiation chain (outer-most last; only one level is possible
   --  here since Direct_IO/Sequential_IO are not themselves declared
   --  inside another generic).
   function Instantiated_Resource_Package
     (Callee : Libadalang.Analysis.Basic_Decl) return String
   is
   begin
      for Inst of Callee.P_Generic_Instantiations loop
         declare
            Name : constant String := Instantiation_Generic_Name (Inst);
         begin
            if Name /= "" then
               return Name;
            end if;
         end;
      end loop;
      return "";
   exception
      when others =>
         return "";
   end Instantiated_Resource_Package;

   --  When Call's name is a dotted call whose prefix resolves to a
   --  Direct_IO/Sequential_IO instantiation, returns the suffix's own
   --  canonical source text (the called member's name, e.g. "open",
   --  "close", "is_open") without needing Libadalang to resolve the
   --  member itself; "" for anything else, including a prefix that
   --  resolves fine but isn't such an instantiation. This is the
   --  fallback FP-062 needed: a package instantiated via a bare generic
   --  name reached only through a "use Ada.Direct_IO;"/"use
   --  Ada.Sequential_IO;" clause (e.g. "package My_IO is new Direct_IO
   --  (Integer);" instead of "... is new Ada.Direct_IO (...);") makes
   --  Libadalang's own P_Referenced_Decl fail to resolve a call into
   --  that package's members (e.g. "My_IO.Create") entirely, even though
   --  the instantiation object's own name ("My_IO") resolves without
   --  issue -- confirmed empirically. Reading the suffix's plain source
   --  text instead of a resolved member's own name sidesteps needing
   --  that broken resolution at all.
   function Resolve_Instantiation_Member
     (Call : Libadalang.Analysis.Call_Expr) return String
   is
   begin
      if Call.F_Name.Kind /= Libadalang.Common.Ada_Dotted_Name then
         return "";
      end if;

      declare
         Dotted : constant Libadalang.Analysis.Dotted_Name :=
           Call.F_Name.As_Dotted_Name;
      begin
         if Dotted.F_Suffix.Kind /= Libadalang.Common.Ada_Identifier then
            return "";
         end if;

         declare
            Prefix_Decl : constant Libadalang.Analysis.Basic_Decl :=
              Dotted.F_Prefix.P_Referenced_Decl (Imprecise_Fallback => True);
         begin
            if Libadalang.Analysis.Is_Null (Prefix_Decl)
              or else Instantiation_Generic_Name (Prefix_Decl) = ""
            then
               return "";
            end if;
            return Canonical_Text (Dotted.F_Suffix);
         end;
      end;
   exception
      when others =>
         return "";
   end Resolve_Instantiation_Member;

   --  Fallback classification for a call whose own name Libadalang
   --  cannot resolve at all (Classify_Resource_Call's own Callee is
   --  null): the FP-062 shape Resolve_Instantiation_Member documents.
   --  There is no resolved member declaration here to read a relative
   --  name from, so the operation comes straight from the call's own
   --  suffix text instead.
   function Classify_Via_Instantiation_Prefix
     (Call : Libadalang.Analysis.Call_Expr) return Resource_Call
   is
      Op_Name : constant String := Resolve_Instantiation_Member (Call);
      Op      : Resource_Op;
   begin
      if Op_Name in "open" | "create" then
         Op := Opens_Resource;
      elsif Op_Name = "close" then
         Op := Closes_Resource;
      else
         return (Op => Not_A_Resource_Call, Decl => Libadalang.Analysis.No_Basic_Decl);
      end if;

      declare
         Actual : constant Libadalang.Analysis.Expr :=
           First_Param_Assoc_Actual (Call);
      begin
         if Libadalang.Analysis.Is_Null (Actual)
           or else Actual.Kind /= Libadalang.Common.Ada_Identifier
         then
            return (Op => Not_A_Resource_Call, Decl => Libadalang.Analysis.No_Basic_Decl);
         end if;
         return (Op => Op, Decl => Data_Flow.Referenced_Declaration (Actual));
      end;
   exception
      when others =>
         return (Op => Not_A_Resource_Call, Decl => Libadalang.Analysis.No_Basic_Decl);
   end Classify_Via_Instantiation_Prefix;

   --  Classifies Stmt as an Open/Create or Close call on an
   --  Ada.Text_IO/Ada.Streams.Stream_IO File_Type object, or on a
   --  File_Type object of a package instantiated from Ada.Direct_IO or
   --  Ada.Sequential_IO (generic, and instantiated per element type the
   --  same way Ada.Unchecked_Deallocation is -- resolving Instantiated_
   --  Resource_Package's instantiation chain rather than matching a fixed
   --  qualified name, since each instantiation mints its own), resolving
   --  the File_Type actual (the first parameter of every one of these
   --  subprograms) to its declaration.
   function Classify_Resource_Call
     (Stmt : Libadalang.Analysis.Call_Stmt) return Resource_Call
   is
      Call : constant Libadalang.Analysis.Name := Stmt.F_Call;
   begin
      if Call.Kind /= Libadalang.Common.Ada_Call_Expr then
         return (Op => Not_A_Resource_Call, Decl => Libadalang.Analysis.No_Basic_Decl);
      end if;

      declare
         Callee : constant Libadalang.Analysis.Basic_Decl :=
           Call.As_Call_Expr.F_Name.P_Referenced_Decl
             (Imprecise_Fallback => True);
      begin
         if Libadalang.Analysis.Is_Null (Callee) then
            return Classify_Via_Instantiation_Prefix (Call.As_Call_Expr);
         end if;

         declare
            Full_Name : constant String := Langkit_Support.Text.To_UTF8
              (Callee.P_Canonical_Fully_Qualified_Name);
            Op        : Resource_Op;
         begin
            if Full_Name in "ada.text_io.open" | "ada.text_io.create"
              | "ada.streams.stream_io.open" | "ada.streams.stream_io.create"
            then
               Op := Opens_Resource;
            elsif Full_Name in "ada.text_io.close"
              | "ada.streams.stream_io.close"
            then
               Op := Closes_Resource;
            elsif Instantiated_Resource_Package (Callee) /= "" then
               declare
                  Op_Name : constant String :=
                    Canonical_Text (Callee.P_Relative_Name);
               begin
                  if Op_Name in "open" | "create" then
                     Op := Opens_Resource;
                  elsif Op_Name = "close" then
                     Op := Closes_Resource;
                  else
                     return
                       (Op => Not_A_Resource_Call,
                        Decl => Libadalang.Analysis.No_Basic_Decl);
                  end if;
               end;
            else
               return (Op => Not_A_Resource_Call, Decl => Libadalang.Analysis.No_Basic_Decl);
            end if;

            declare
               Actual : constant Libadalang.Analysis.Expr :=
                 First_Param_Assoc_Actual (Call.As_Call_Expr);
            begin
               if Libadalang.Analysis.Is_Null (Actual)
                 or else Actual.Kind /= Libadalang.Common.Ada_Identifier
               then
                  return (Op => Not_A_Resource_Call, Decl => Libadalang.Analysis.No_Basic_Decl);
               end if;

               return (Op => Op, Decl => Data_Flow.Referenced_Declaration (Actual));
            end;
         end;
      end;
   exception
      when others =>
         return (Op => Not_A_Resource_Call, Decl => Libadalang.Analysis.No_Basic_Decl);
   end Classify_Resource_Call;

   --  True when Cond is a call to Ada.Text_IO.Is_Open,
   --  Ada.Streams.Stream_IO.Is_Open, or the Is_Open of a package
   --  instantiated from Ada.Direct_IO/Ada.Sequential_IO, on Decl -- the
   --  standard "if Is_Open (File) then Close (File); end if;" idiom for
   --  closing a file that might already be closed (calling Close on an
   --  unopened or already-closed File_Type raises Status_Error, so this
   --  guard is the correct, common way to write an idempotent close).
   --  Recognized so Interpret_Closure can treat the missing "else" branch
   --  as safe too, rather than pessimistically inheriting whatever state
   --  came before the if -- without this, the idiom itself (used correctly
   --  in this project's own Report.Load_Baseline) false-positives every
   --  time.
   function Guards_Is_Open
     (Cond : Libadalang.Analysis.Expr;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Cond)
        or else Cond.Kind /= Libadalang.Common.Ada_Call_Expr
      then
         return False;
      end if;

      declare
         Callee : constant Libadalang.Analysis.Basic_Decl :=
           Cond.As_Call_Expr.F_Name.P_Referenced_Decl
             (Imprecise_Fallback => True);
      begin
         if Libadalang.Analysis.Is_Null (Callee) then
            --  FP-062 fallback: see Resolve_Instantiation_Member.
            if Resolve_Instantiation_Member (Cond.As_Call_Expr) /= "is_open"
            then
               return False;
            end if;
         else
            declare
               Full_Name : constant String := Langkit_Support.Text.To_UTF8
                 (Callee.P_Canonical_Fully_Qualified_Name);
            begin
               if Full_Name /= "ada.text_io.is_open"
                 and then Full_Name /= "ada.streams.stream_io.is_open"
                 and then not
                   (Instantiated_Resource_Package (Callee) /= ""
                    and then Canonical_Text (Callee.P_Relative_Name) =
                      "is_open")
               then
                  return False;
               end if;
            end;
         end if;

         declare
            Actual : constant Libadalang.Analysis.Expr :=
              First_Param_Assoc_Actual (Cond.As_Call_Expr);
         begin
            return not Libadalang.Analysis.Is_Null (Actual)
              and then Actual.Kind = Libadalang.Common.Ada_Identifier
              and then Data_Flow.Referenced_Declaration (Actual) = Decl;
         end;
      end;
   exception
      when others =>
         return False;
   end Guards_Is_Open;

   --  When Node sits directly in the then-branch statement list of a bare
   --  "if <Cond> then ... end if;" (no elsif, no else), returns that
   --  condition's canonical text; otherwise "". Used to recognize the
   --  "opened only when <Cond>, closed later only when <Cond>" idiom (seen
   --  in this project's own Compliance_Mapping report writer, guarded by
   --  "To_File") as symmetric with Guards_Is_Open: if the same textual
   --  guard shields both the open and a later close, the untaken branch on
   --  either side means the file was never opened, which is just as safe
   --  as having closed it.
   function Enclosing_Bare_If_Guard
     (Node : Libadalang.Analysis.Ada_Node'Class) return String
   is
      Parent : constant Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      if Libadalang.Analysis.Is_Null (Parent)
        or else Libadalang.Analysis.Is_Null (Parent.Parent)
        or else Parent.Parent.Kind /= Libadalang.Common.Ada_If_Stmt
      then
         return "";
      end if;

      declare
         Stmt : constant Libadalang.Analysis.If_Stmt :=
           Parent.Parent.As_If_Stmt;
      begin
         if Libadalang.Analysis.Ada_Node (Stmt.F_Then_Stmts) /= Parent
           or else not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
           or else Stmt.F_Alternatives.Children_Count /= 0
         then
            return "";
         end if;
         return Canonical_Text (Stmt.F_Cond_Expr);
      end;
   exception
      when others =>
         return "";
   end Enclosing_Bare_If_Guard;

   --  Whole-subtree search used for the conservative loop-body fallback
   --  below: True when some statement anywhere under Node closes Decl,
   --  without proving it happens on every, or even one, iteration.
   function References_Close
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt then
         declare
            Info : constant Resource_Call :=
              Classify_Resource_Call (Node.As_Call_Stmt);
         begin
            if Info.Op = Closes_Resource and then Info.Decl = Decl then
               return True;
            end if;
         end;
      end if;

      for I in 1 .. Node.Children_Count loop
         if References_Close (Node.Child (I), Decl) then
            return True;
         end if;
      end loop;

      return False;
   exception
      when others =>
         return False;
   end References_Close;

   --  True when Node's subtree contains an exit statement anywhere, at
   --  any nesting depth -- deliberately not narrowed to "targets this
   --  loop" (a labeled exit reaching this loop from inside a nested one
   --  is a rare shape this project doesn't attempt to distinguish from
   --  an unrelated inner exit). Used to keep the precise loop-body
   --  fixed-point analysis below scoped to loops whose only way out is
   --  their own head test or an internal return/raise/goto -- both
   --  already modeled -- falling back to the older References_Close
   --  heuristic whenever an exit could skip either.
   function Contains_Exit_Statement
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Exit_Stmt then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if Contains_Exit_Statement (Node.Child (I)) then
            return True;
         end if;
      end loop;

      return False;
   exception
      when others =>
         return False;
   end Contains_Exit_Statement;

   --  True when Node is a numeric "for I in Low .. High loop" (not a "for
   --  X of/in <iterable>" container form) whose iteration range is
   --  statically known to be non-empty (Low <= High) -- the same
   --  static-bounds proof Spark_Readiness's own Uninitialized_Output
   --  for-loop coverage check uses to trust that a for-loop runs its body
   --  at least once (its own "Scalar" case), reused here so a provably
   --  non-empty for-loop gets the same "guaranteed at least one
   --  iteration" treatment a bare, unconditional loop already gets below.
   --  Choice_Interval's default Empty_Flow_State means only bounds that
   --  are themselves static (literals, or expressions built from them)
   --  are recognized; a loop bounded by a variable or an as-yet-untracked
   --  subtype's own declared range is conservatively left as possibly
   --  empty, same as before this function existed.
   function Provably_Nonempty_For_Loop
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Node.Kind /= Libadalang.Common.Ada_For_Loop_Stmt then
         return False;
      end if;

      declare
         Spec : constant Libadalang.Analysis.For_Loop_Spec :=
           Node.As_For_Loop_Stmt.F_Spec.As_For_Loop_Spec;
      begin
         if Spec.F_Loop_Type.Kind /= Libadalang.Common.Ada_Iter_Type_In then
            return False;
         end if;

         declare
            Bounds : constant Static_Interval :=
              Choice_Interval (Spec.F_Iter_Expr);
         begin
            return Bounds.Known and then Bounds.Low <= Bounds.High;
         end;
      end;
   exception
      when others =>
         return False;
   end Provably_Nonempty_For_Loop;

   type Close_Result is record
      Can_Fall_Through : Boolean := True;
      Safe             : Boolean := True;
      --  Safe: the tracked File_Type object is not currently open, either
      --  because Open_At hasn't been reached yet or because a matching
      --  Close already ran. False means it is open and unclosed.
   end record;

   function Merge (Left, Right : Close_Result) return Close_Result is
   begin
      if not Left.Can_Fall_Through then
         return Right;
      elsif not Right.Can_Fall_Through then
         return Left;
      else
         return
           (Can_Fall_Through => True,
            Safe             => Left.Safe and then Right.Safe);
      end if;
   end Merge;

   function Interpret_Closure
     (Node        : Libadalang.Analysis.Ada_Node'Class;
      Decl        : Libadalang.Analysis.Basic_Decl;
      Open_At     : Libadalang.Analysis.Ada_Node;
      Open_Guard  : String;
      Initial     : Boolean;
      Bad_Exit    : in out Boolean) return Close_Result;

   function Interpret_Closure_List
     (List        : Libadalang.Analysis.Ada_Node'Class;
      Decl        : Libadalang.Analysis.Basic_Decl;
      Open_At     : Libadalang.Analysis.Ada_Node;
      Open_Guard  : String;
      Initial     : Boolean;
      Bad_Exit    : in out Boolean) return Close_Result
   is
      Result : Close_Result := (Can_Fall_Through => True, Safe => Initial);
   begin
      for I in 1 .. List.Children_Count loop
         exit when not Result.Can_Fall_Through;
         Result := Interpret_Closure
           (List.Child (I), Decl, Open_At, Open_Guard, Result.Safe, Bad_Exit);
      end loop;
      return Result;
   end Interpret_Closure_List;

   --  Structural recursive interpreter modeled on
   --  Adalang_Analyzer.Spark_Readiness's Interpret_Initialization (the
   --  engine behind Uninitialized_Output): same Can_Fall_Through/state
   --  record shape and the same If/Case/Decl_Block statement-list merge,
   --  but tracking "is the file currently open" (Safe = False) rather than
   --  "is the parameter initialized." Reaching Open_At itself flips Safe to
   --  False; a matching Close flips it back to True. Bad_Exit mirrors
   --  Uninitialized_Output's Bad_Return: a Return/Raise/Goto reached while
   --  unsafe is itself a violation, independent of what sibling branches
   --  do, so it cannot be captured by Merge alone (Merge is only about the
   --  state carried into whatever code follows this construct).
   function Interpret_Closure
     (Node        : Libadalang.Analysis.Ada_Node'Class;
      Decl        : Libadalang.Analysis.Basic_Decl;
      Open_At     : Libadalang.Analysis.Ada_Node;
      Open_Guard  : String;
      Initial     : Boolean;
      Bad_Exit    : in out Boolean) return Close_Result
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return (True, Initial);
      elsif Libadalang.Analysis.Ada_Node (Node) = Open_At then
         return (True, False);
      elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt then
         declare
            Info : constant Resource_Call :=
              Classify_Resource_Call (Node.As_Call_Stmt);
         begin
            if Info.Op = Closes_Resource and then Info.Decl = Decl then
               return (True, True);
            end if;
         end;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt
            | Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            Bad_Exit := Bad_Exit or else not Initial;
            return (False, Initial);

         when Libadalang.Common.Ada_If_Stmt =>
            declare
               Stmt        : constant Libadalang.Analysis.If_Stmt :=
                 Node.As_If_Stmt;
               Then_Result : constant Close_Result := Interpret_Closure_List
                 (Stmt.F_Then_Stmts, Decl, Open_At, Open_Guard, Initial,
                  Bad_Exit);
            begin
               if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
                 and then Stmt.F_Alternatives.Children_Count = 0
                 and then Then_Result.Can_Fall_Through
                 and then Then_Result.Safe
                 and then (Guards_Is_Open (Stmt.F_Cond_Expr, Decl)
                           or else
                             (Open_Guard /= ""
                              and then Canonical_Text (Stmt.F_Cond_Expr) =
                                Open_Guard))
               then
                  return Then_Result;
               end if;

               declare
                  Result : Close_Result := Then_Result;
               begin
                  for Alt of Stmt.F_Alternatives loop
                     Result := Merge
                       (Result,
                        Interpret_Closure_List
                          (Alt.F_Stmts, Decl, Open_At, Open_Guard, Initial,
                           Bad_Exit));
                  end loop;
                  if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
                     Result := Merge (Result, (True, Initial));
                  else
                     Result := Merge
                       (Result,
                        Interpret_Closure_List
                          (Stmt.F_Else_Part.F_Stmts, Decl, Open_At,
                           Open_Guard, Initial, Bad_Exit));
                  end if;
                  return Result;
               end;
            end;

         when Libadalang.Common.Ada_Case_Stmt =>
            declare
               First  : Boolean := True;
               Result : Close_Result := (False, Initial);
            begin
               for Alt of Node.As_Case_Stmt.F_Alternatives loop
                  declare
                     Branch : constant Close_Result := Interpret_Closure_List
                       (Alt.F_Stmts, Decl, Open_At, Open_Guard, Initial,
                        Bad_Exit);
                  begin
                     if First then
                        Result := Branch;
                        First := False;
                     else
                        Result := Merge (Result, Branch);
                     end if;
                  end;
               end loop;
               return Result;
            end;

         when Libadalang.Common.Ada_Decl_Block =>
            return Interpret_Closure_List
              (Node.As_Decl_Block.F_Stmts.F_Stmts, Decl, Open_At, Open_Guard,
               Initial, Bad_Exit);

         when Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt
            | Libadalang.Common.Ada_For_Loop_Stmt =>
            declare
               Body_Stmts : constant Libadalang.Analysis.Stmt_List :=
                 Node.As_Base_Loop_Stmt.F_Stmts;
            begin
               --  An exit anywhere in the body (see Contains_Exit_Statement)
               --  keeps the older, purely textual fallback: credit the
               --  resource as closed if a matching Close call appears
               --  anywhere in the loop body, without proving the loop
               --  actually executes or that the exit doesn't skip past it.
               --  False-negative biased, so a loop that legitimately
               --  closes the resource on some or all iterations is never
               --  flagged.
               if Contains_Exit_Statement (Body_Stmts) then
                  if not Initial
                    and then References_Close (Body_Stmts, Decl)
                  then
                     return (True, True);
                  end if;
                  return (True, Initial);
               end if;

               --  No exit: the only ways out of a While/For loop are its
               --  own head test (possibly zero iterations, unless proven
               --  otherwise below) and an internal return/raise/goto
               --  (already tracked via Can_Fall_Through/Bad_Exit); a
               --  bare, unconditional loop has no head test of its own,
               --  so with no exit anywhere either, the code after it is
               --  always unreachable via normal control flow (a path
               --  that completes the body normally just repeats the loop
               --  forever; every other path already transferred out
               --  rather than falling through to here) -- exactly the
               --  same "always at least one iteration, and completing
               --  one normally never itself reaches past the loop"
               --  reasoning also applies to a For loop whose range is
               --  proven non-empty (Provably_Nonempty_For_Loop): its own
               --  head test can never be false on the first pass, and
               --  completing a later pass normally just starts the next
               --  one, so the only way "after the loop" is reached at
               --  all is via the last iteration's own normal completion
               --  once the range is exhausted -- never via a test that
               --  could fail before any iteration ran. Interpreting the
               --  body once from the real entry state (First) gives the
               --  effect of running it starting from wherever the loop is
               --  actually entered; since nothing in this interpreter's
               --  state besides the single Safe flag threads between
               --  statements, and Open_At (the only thing that can ever
               --  force Safe back to False) is reached the same way
               --  regardless of the incoming flag, re-interpreting the
               --  body from First's own exit state (Second) always
               --  reproduces a genuine fixed point in at most this one
               --  extra application -- the effect of any second or later
               --  iteration, however many the loop actually runs.
               declare
                  Guaranteed_At_Least_Once : constant Boolean :=
                    Node.Kind = Libadalang.Common.Ada_Loop_Stmt
                      or else Provably_Nonempty_For_Loop (Node);
                  First : constant Close_Result := Interpret_Closure_List
                    (Body_Stmts, Decl, Open_At, Open_Guard, Initial,
                     Bad_Exit);
               begin
                  if not First.Can_Fall_Through then
                     if Guaranteed_At_Least_Once then
                        --  The loop's one guaranteed iteration (or every
                        --  iteration, for a bare loop) always transfers
                        --  out early; there is no head test that could
                        --  still be reached to fall through normally.
                        return (False, Initial);
                     end if;
                     --  While/For, not proven non-empty: the only way to
                     --  reach the code after this loop is the
                     --  zero-iteration path, which leaves the state
                     --  exactly as it entered.
                     return (True, Initial);
                  end if;

                  if Node.Kind = Libadalang.Common.Ada_Loop_Stmt then
                     --  A bare loop completing its body normally only
                     --  repeats it forever (checked above: no exit
                     --  anywhere); "after the loop" stays unreachable
                     --  regardless of what a further iteration would do.
                     return (False, Initial);
                  end if;

                  declare
                     Second : constant Close_Result := Interpret_Closure_List
                       (Body_Stmts, Decl, Open_At, Open_Guard, First.Safe,
                        Bad_Exit);
                     One_Or_More : constant Close_Result :=
                       (if Second.Can_Fall_Through
                        then (True, Second.Safe)
                        else (True, First.Safe));
                  begin
                     if Guaranteed_At_Least_Once then
                        --  A provably non-empty For loop: no zero-
                        --  iteration path exists to merge in.
                        return One_Or_More;
                     end if;
                     --  While/For, not proven non-empty: merge the
                     --  zero-iteration outcome (the entry state,
                     --  unchanged) with the one-or-more-iterations
                     --  outcome, since either is possible.
                     return Merge ((True, Initial), One_Or_More);
                  end;
               end;
            end;

         when others =>
            return (True, Initial);
      end case;
   end Interpret_Closure;

   --  Runs the interpreter above once for one Open/Create call site
   --  (Open_At, resolved to Decl), over the whole subprogram body plus,
   --  separately and conservatively (Initial => False: an exception could
   --  strike between Open and Close), every exception handler -- the same
   --  two-pass structure Uninitialized_Output uses for its own all-paths
   --  check.
   procedure Check_Closed_On_Every_Path
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body;
      Decl       : Libadalang.Analysis.Basic_Decl;
      Open_At    : Libadalang.Analysis.Ada_Node)
   is
      Open_Guard    : constant String := Enclosing_Bare_If_Guard (Open_At);
      Bad_Exit      : Boolean := False;
      Body_Result   : constant Close_Result := Interpret_Closure_List
        (Subprogram.F_Stmts.F_Stmts, Decl, Open_At, Open_Guard, True,
         Bad_Exit);
      Report_Needed : Boolean :=
        Bad_Exit
          or else (Body_Result.Can_Fall_Through
                    and then not Body_Result.Safe);
   begin
      if not Report_Needed then
         for Handler of Subprogram.F_Stmts.F_Exceptions loop
            if Handler.Kind = Libadalang.Common.Ada_Exception_Handler then
               declare
                  Handler_Bad_Exit : Boolean := False;
                  Handler_Result   : constant Close_Result :=
                    Interpret_Closure_List
                      (Handler.As_Exception_Handler.F_Stmts, Decl, Open_At,
                       Open_Guard, False, Handler_Bad_Exit);
               begin
                  if Handler_Bad_Exit
                    or else (Handler_Result.Can_Fall_Through
                             and then not Handler_Result.Safe)
                  then
                     Report_Needed := True;
                     exit;
                  end if;
               end;
            end if;
         end loop;
      end if;

      if Report_Needed then
         Report_Rule_Violation
           (Unit, Open_At, Unclosed_File_Handle,
            "file opened here is not demonstrably closed on every " &
              "path out of this subprogram, including exception " &
              "handlers");
      end if;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping unresolved resource-lifecycle analysis: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Check_Closed_On_Every_Path;

   --  Unclosed_File_Handle entry point: for every local File_Type object
   --  opened anywhere in the subprogram, including inside a loop --
   --  Interpret_Closure's own loop case now reasons about the loop body's
   --  fixed point rather than bailing on any loop-scoped open -- checks
   --  that every reachable normal and exception-handler path closes it.
   --  One independent interpreter run per Open/Create call site, so a
   --  File_Type reopened more than once is checked separately for each
   --  occurrence.
   procedure Analyze_Resource_Lifecycle
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      procedure Scan (Node : Libadalang.Analysis.Ada_Node'Class);

      procedure Scan (Node : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         end if;

         if Node.Kind = Libadalang.Common.Ada_Call_Stmt then
            begin
               declare
                  Info : constant Resource_Call :=
                    Classify_Resource_Call (Node.As_Call_Stmt);
               begin
                  if Info.Op = Opens_Resource
                    and then not Libadalang.Analysis.Is_Null (Info.Decl)
                    and then Info.Decl.Kind in
                      Libadalang.Common.Ada_Object_Decl_Range
                    and then Is_Local_To_Subprogram (Info.Decl, Subprogram)
                    and then not Renames_Nonlocal_Object
                      (Info.Decl, Subprogram)
                  then
                     Check_Closed_On_Every_Path
                       (Unit, Subprogram, Info.Decl,
                        Libadalang.Analysis.Ada_Node (Node));
                  end if;
               end;
            exception
               when Exc : others =>
                  --  An unresolved call profile is conservatively skipped.
                  Log_Verbose_Once
                    ("skipping unresolved resource-open candidate: " &
                     Ada.Exceptions.Exception_Message (Exc));
            end;
         end if;

         for I in 1 .. Node.Children_Count loop
            Scan (Node.Child (I));
         end loop;
      end Scan;
   begin
      if Rule_States (Unclosed_File_Handle) /= Enabled then
         return;
      end if;
      Scan (Subprogram.F_Stmts.F_Stmts);
   end Analyze_Resource_Lifecycle;

   --  Use_After_Free: Stmt is a call to a Free-like procedure introduced by
   --  an Ada.Unchecked_Deallocation instantiation (recognized the same way
   --  No_Unchecked_Deallocation recognizes the instantiation itself, via
   --  Checks.Is_Ada_Unchecked_Deallocation, but resolved from the call's
   --  own callee declaration instead of an instantiation node). When the
   --  freed actual is a simple local object, First_Access finds the first
   --  read or write of it anywhere at or after the call: a write (typically
   --  "P := null;") makes the object safe again and is not reported, while
   --  a read with no intervening write is a use-after-free. Inherits
   --  First_Access's documented source-order (not branch-sensitive)
   --  boundary, the same tradeoff Uninitialized_Read already accepts.
   procedure Analyze_Deallocation_Call
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Call_Stmt;
      Call : Libadalang.Analysis.Call_Expr)
   is
      Callee_Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call.F_Name.P_Referenced_Decl (Imprecise_Fallback => True);
   begin
      if Libadalang.Analysis.Is_Null (Callee_Decl)
        or else Callee_Decl.Kind /=
          Libadalang.Common.Ada_Generic_Subp_Instantiation
        or else not Adalang_Analyzer.Checks.Is_Ada_Unchecked_Deallocation
          (Callee_Decl.As_Generic_Subp_Instantiation.F_Generic_Subp_Name)
      then
         return;
      end if;

      declare
         Suffix : constant Libadalang.Analysis.Ada_Node := Call.F_Suffix;
         Actual : Libadalang.Analysis.Expr := Libadalang.Analysis.No_Expr;
      begin
         for Index in 1 .. Suffix.Children_Count loop
            declare
               Child : constant Libadalang.Analysis.Ada_Node :=
                 Suffix.Child (Index);
            begin
               if Child.Kind = Libadalang.Common.Ada_Param_Assoc then
                  Actual := Child.As_Param_Assoc.F_R_Expr;
                  exit;
               end if;
            end;
         end loop;

         if Libadalang.Analysis.Is_Null (Actual)
           or else Actual.Kind /= Libadalang.Common.Ada_Identifier
         then
            return;
         end if;

         declare
            Decl       : constant Libadalang.Analysis.Basic_Decl :=
              Data_Flow.Referenced_Declaration (Actual);
            Subprogram : constant Libadalang.Analysis.Subp_Body :=
              Data_Flow.Enclosing_Subprogram (Stmt);
         begin
            if Libadalang.Analysis.Is_Null (Decl)
              or else Decl.Kind not in Libadalang.Common.Ada_Object_Decl_Range
              or else Libadalang.Analysis.Is_Null (Subprogram)
              or else not Is_Local_To_Subprogram (Decl, Subprogram)
              or else Renames_Nonlocal_Object (Decl, Subprogram)
            then
               return;
            end if;

            declare
               Result : constant Data_Flow.Access_Result :=
                 Data_Flow.First_Access (Subprogram, Decl, Stmt);
            begin
               if Result.Kind = Data_Flow.Read_Access then
                  Report_Rule_Violation
                    (Unit, Result.Node, Use_After_Free,
                     "reads " & Canonical_Text (Actual) &
                       ", which was freed by an earlier call to " &
                       "Ada.Unchecked_Deallocation, with no intervening " &
                       "assignment");
               end if;
            end;
         end;
      end;
   exception
      when Exc : others =>
         --  An unresolved call profile is conservatively skipped.
         Log_Verbose_Once
           ("skipping unresolved deallocation call: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Analyze_Deallocation_Call;

   procedure Analyze_Call_Statement
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Call_Stmt)
   is
      Call : constant Libadalang.Analysis.Name := Stmt.F_Call;
   begin
      if Rule_States (Use_After_Free) = Enabled
        and then Call.Kind = Libadalang.Common.Ada_Call_Expr
      then
         Analyze_Deallocation_Call (Unit, Stmt, Call.As_Call_Expr);
      end if;

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
                             and then not Data_Flow.Is_Externally_Observable
                               (Decl)
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
                     when Exc : others =>
                        --  An unresolved call profile is conservatively
                        --  skipped.
                        Log_Verbose_Once
                          ("skipping unresolved call profile: " &
                           Ada.Exceptions.Exception_Message (Exc));
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
      Report_Identical_Case_Alternatives (Unit, Alternatives);
      Report_Null_Case_Alternatives (Unit, Alternatives);

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

   --  True when Node's subtree contains a pragma spelled Pragma_Name,
   --  without descending into a nested loop or subprogram body -- their own
   --  Loop_Invariant/Loop_Variant pragmas belong to that inner loop, not the
   --  one Analyze_Loop_Variant_Presence is currently checking. Mirrors
   --  Has_Loop_Termination's nested-loop scoping above.
   function Has_Loop_Pragma
     (Node        : Libadalang.Analysis.Ada_Node'Class;
      Pragma_Name : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_Subp_Body =>
            return False;

         when Libadalang.Common.Ada_Pragma_Node =>
            return
              Canonical_Text (Node.As_Pragma_Node.F_Id) = Pragma_Name;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         if Has_Loop_Pragma (Node.Child (I), Pragma_Name) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Loop_Pragma;

   --  Reports Missing_Loop_Variant when Loop_Node carries a Loop_Invariant
   --  pragma (signalling proof intent) but no Loop_Variant pragma, so
   --  GNATprove has no termination measure to check.
   procedure Analyze_Loop_Variant_Presence
     (Unit      : Libadalang.Analysis.Analysis_Unit;
      Loop_Node : Libadalang.Analysis.Base_Loop_Stmt)
   is
   begin
      if Rule_States (Missing_Loop_Variant) = Enabled
        and then Has_Loop_Pragma (Loop_Node.F_Stmts, "loop_invariant")
        and then not Has_Loop_Pragma (Loop_Node.F_Stmts, "loop_variant")
      then
         Report_Rule_Violation
           (Unit, Loop_Node, Missing_Loop_Variant,
            "loop has a Loop_Invariant pragma but no Loop_Variant pragma");
      end if;
   end Analyze_Loop_Variant_Presence;

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

   --  True when Node is the identifier "True" or "False" and its static
   --  type actually resolves to Standard.Boolean, as opposed to a
   --  user-declared enumeration type that merely has a same-spelled
   --  literal. Backs Redundant_If_Boolean_Return; mirrors
   --  Checks.Expressions.Is_Standard_Boolean_Expression, used there for
   --  the identical concern in Redundant_Boolean_Comparison.
   function Is_Standard_Boolean_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if not Is_Boolean_Literal (Node) then
         return False;
      end if;

      declare
         Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Node.As_Expr.P_Expression_Type;
      begin
         return not Libadalang.Analysis.Is_Null (Expr_Type)
           and then Langkit_Support.Text.To_UTF8
             (Expr_Type.P_Canonical_Fully_Qualified_Name) =
             "standard.boolean";
      end;
   exception
      when others =>
         --  Name resolution can legitimately fail for incomplete source.
         return False;
   end Is_Standard_Boolean_Literal;

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

            if Rule_States (Empty_Elsif_Body) = Enabled
              and then not Has_Substantive_Statement (Alt.F_Stmts)
            then
               Report_Rule_Violation
                 (Unit, Alt, Empty_Elsif_Body,
                  "elsif branch has no effect because its body is empty");
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

      --  Unlike Empty_If_Body, deliberately not scoped to "no elsif and no
      --  else": an empty then branch still has no effect on its own even
      --  when a later elsif or else does real work, since the two are
      --  mutually exclusive at runtime.
      if Rule_States (Empty_Then_Body) = Enabled
        and then (Alternatives.Children_Count > 0
                  or else not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part))
        and then not Has_Substantive_Statement (Stmt.F_Then_Stmts)
      then
         Report_Rule_Violation
           (Unit, Stmt, Empty_Then_Body,
            "then branch has no effect because its body is empty");
      end if;

      if Rule_States (Empty_Else_Body) = Enabled
        and then not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
        and then not Has_Substantive_Statement (Stmt.F_Else_Part.F_Stmts)
      then
         Report_Rule_Violation
           (Unit, Stmt.F_Else_Part, Empty_Else_Body,
            "else branch has no effect because its body is empty");
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

      if Rule_States (Redundant_If_Boolean_Return) = Enabled
        and then Alternatives.Children_Count = 0
        and then not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
        and then Stmt.F_Then_Stmts.Children_Count = 1
        and then Stmt.F_Else_Part.F_Stmts.Children_Count = 1
        and then Stmt.F_Then_Stmts.Child (1).Kind =
          Libadalang.Common.Ada_Return_Stmt
        and then Stmt.F_Else_Part.F_Stmts.Child (1).Kind =
          Libadalang.Common.Ada_Return_Stmt
      then
         declare
            Then_Expr : constant Libadalang.Analysis.Ada_Node :=
              Libadalang.Analysis.Ada_Node
                (Stmt.F_Then_Stmts.Child (1).As_Return_Stmt.F_Return_Expr);
            Else_Expr : constant Libadalang.Analysis.Ada_Node :=
              Libadalang.Analysis.Ada_Node
                (Stmt.F_Else_Part.F_Stmts.Child
                   (1).As_Return_Stmt.F_Return_Expr);
         begin
            if Is_Standard_Boolean_Literal (Then_Expr)
              and then Is_Standard_Boolean_Literal (Else_Expr)
              and then Boolean_Value (Then_Expr) /= Boolean_Value (Else_Expr)
            then
               Report_Rule_Violation
                 (Unit, Stmt, Redundant_If_Boolean_Return,
                  "if statement returns an opposite boolean literal on " &
                  "each branch and can be simplified to returning the " &
                  "condition" &
                  (if Boolean_Value (Then_Expr) = Bool_False
                   then " negated" else ""));
            end if;
         end;
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

   --  True when Handler's own choice list handles "when others".
   function Handles_Others
     (Handler : Libadalang.Analysis.Exception_Handler) return Boolean
   is
   begin
      for Choice of Handler.F_Handled_Exceptions loop
         if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
            return True;
         end if;
      end loop;
      return False;
   end Handles_Others;

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

      if Rule_States (Duplicate_Exception_Choice) = Enabled then
         for I in 2 .. Handler.F_Handled_Exceptions.Children_Count loop
            declare
               Choice      : constant Libadalang.Analysis.Ada_Node :=
                 Handler.F_Handled_Exceptions.Child (I);
               Choice_Text : constant String := Canonical_Text (Choice);
            begin
               if Choice.Kind /= Libadalang.Common.Ada_Others_Designator
                 and then Choice_Text /= ""
               then
                  for J in 1 .. I - 1 loop
                     if Canonical_Text
                       (Handler.F_Handled_Exceptions.Child (J)) =
                       Choice_Text
                     then
                        Report_Rule_Violation
                          (Unit, Choice, Duplicate_Exception_Choice,
                           "exception choice repeats an earlier choice in " &
                           "the same handler");
                        exit;  --  adalang-analyzer: ignore No_Exit
                     end if;
                  end loop;
               end if;
            end;
         end loop;
      end if;

      if Rule_States (Handler_Order) = Enabled then
         declare
            Earlier : Libadalang.Analysis.Ada_Node :=
              Libadalang.Analysis.Ada_Node (Handler).Previous_Sibling;
         begin
            while not Libadalang.Analysis.Is_Null (Earlier) loop
               if Earlier.Kind = Libadalang.Common.Ada_Exception_Handler
                 and then Handles_Others (Earlier.As_Exception_Handler)
               then
                  Report_Rule_Violation
                    (Unit, Handler, Handler_Order,
                     "handler is unreachable because an earlier when " &
                       "others handler already catches every exception");
                  exit;  --  adalang-analyzer: ignore No_Exit
               end if;
               Earlier := Earlier.Previous_Sibling;
            end loop;
         end;
      end if;

      if Rule_States (Exception_Swallowed) = Enabled then
         if Handles_Others (Handler)
           and then not Has_Substantive_Statement (Handler.F_Stmts)
         then
            Report_Rule_Violation
              (Unit, Handler, Exception_Swallowed,
               "when others handler silently discards the exception");
         end if;
      end if;

      if Rule_States (Reraise_Discards_Occurrence) = Enabled
        and then Handler.F_Handled_Exceptions.Children_Count = 1
        and then Handler.F_Handled_Exceptions.Child (1).Kind /=
          Libadalang.Common.Ada_Others_Designator
        and then Handler.F_Stmts.Children_Count > 0
      then
         declare
            Caught_Name : constant String :=
              Canonical_Text (Handler.F_Handled_Exceptions.Child (1));
            Last_Stmt   : constant Libadalang.Analysis.Ada_Node :=
              Handler.F_Stmts.Child (Handler.F_Stmts.Children_Count);
         begin
            if Last_Stmt.Kind = Libadalang.Common.Ada_Raise_Stmt
              and then not Libadalang.Analysis.Is_Null
                (Last_Stmt.As_Raise_Stmt.F_Exception_Name)
              and then Canonical_Text
                (Last_Stmt.As_Raise_Stmt.F_Exception_Name) = Caught_Name

              --  "raise Foo with "<context>";" deliberately replaces the
              --  message with added diagnostic context before
              --  re-propagating -- a legitimate enrich-and-reraise idiom,
              --  not the accidental message/traceback loss this check
              --  targets. Only a bare "raise Foo;" (no message) is flagged.
              and then Libadalang.Analysis.Is_Null
                (Last_Stmt.As_Raise_Stmt.F_Error_Message)
            then
               Report_Rule_Violation
                 (Unit, Last_Stmt, Reraise_Discards_Occurrence,
                  "re-raises the caught exception by name instead of a " &
                  "bare 'raise;'");
            end if;
         end;
      end if;
   end Analyze_Exception_Handler;

end Adalang_Analyzer.Checks.Control_Flow;
