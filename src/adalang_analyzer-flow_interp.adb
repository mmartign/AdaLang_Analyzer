--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Common;
with Langkit_Support.Text;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Domain; use Adalang_Analyzer.Flow_Domain;
with Adalang_Analyzer.Flow_Eval;   use Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Flow_Interp is

   use type Libadalang.Common.Ada_Node_Kind_Type;

   --  Fetches an aspect from any declaration/body part. Missing or
   --  unresolved contracts are represented by a null expression.
   function Contract_Expression
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Libadalang.Analysis.Expr
   is
      Result : Libadalang.Analysis.Expr;
   begin
      Result := Decl.P_Get_Aspect_Spec_Expr
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Name)));
      if Libadalang.Analysis.Is_Null (Result)
        and then Decl.Kind = Libadalang.Common.Ada_Subp_Body
      then
         declare
            Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
              Decl.As_Subp_Body.P_Decl_Part
                (Imprecise_Fallback => True);
         begin
            if not Libadalang.Analysis.Is_Null (Decl_Part) then
               Result := Decl_Part.P_Get_Aspect_Spec_Expr
                 (Langkit_Support.Text.To_Unbounded_Text
                    (Langkit_Support.Text.To_Text (Name)));
            end if;
         end;
      end if;
      return Result;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Contract_Expression;

   --  The defining name an identifier resolves to, or No_Ada_Node for
   --  anything else. The Flow_State key type; kept distinct from a
   --  Basic_Decl resolution, which cannot tell apart two names introduced
   --  by one multi-name declaration.
   function Flow_Referenced_Name
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Flow_Referenced_Name;

   --  The defining name written by an assignment whose destination is a
   --  plain identifier, or No_Ada_Node for anything else (a more complex
   --  destination such as an array or record component).
   function Flow_Assigned_Name
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Assign_Stmt
        or else Node.As_Assign_Stmt.F_Dest.Kind /=
          Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      return Flow_Referenced_Name (Node.As_Assign_Stmt.F_Dest);
   end Flow_Assigned_Name;

   function Normalized_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      return Text_Utils.Normalize_Rule_Name (Ada_Text.Node_Text (Node));
   end Normalized_Text;

   function Call_Declaration
     (Call : Libadalang.Analysis.Name'Class)
      return Libadalang.Analysis.Basic_Decl is
   begin
      if Call.Kind = Libadalang.Common.Ada_Call_Expr then
         return Call.As_Call_Expr.F_Name.P_Referenced_Decl;
      else
         return Call.P_Referenced_Decl;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Call_Declaration;

   function Effective_SPARK_Enabled
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Aspect : Libadalang.Analysis.Aspect;
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return True;
      end if;

      Aspect := Decl.P_Get_Aspect
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text ("SPARK_Mode")));

      return not Libadalang.Analysis.Exists (Aspect)
        or else Libadalang.Analysis.Is_Null
          (Libadalang.Analysis.Value (Aspect))
        or else Normalized_Text (Libadalang.Analysis.Value (Aspect)) /= "off";
   exception
      when others =>
         return True;
   end Effective_SPARK_Enabled;

   function Formal_Mode
     (Param : Libadalang.Analysis.Defining_Name'Class)
      return Libadalang.Common.Ada_Node_Kind_Type
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Param);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return Current.As_Param_Spec.F_Mode;
         end if;
         Current := Current.Parent;
      end loop;

      return Libadalang.Common.Ada_Mode_Default;
   exception
      when others =>
         return Libadalang.Common.Ada_Mode_Default;
   end Formal_Mode;

   function Formal_Is_Writable
     (Param : Libadalang.Analysis.Defining_Name'Class) return Boolean is
   begin
      return Formal_Mode (Param) in Libadalang.Common.Ada_Mode_Out
        | Libadalang.Common.Ada_Mode_In_Out;
   end Formal_Is_Writable;

   procedure Seed_Formal_Values
     (Call            : Libadalang.Analysis.Name'Class;
      Caller_State    : Flow_State;
      Include_Outputs : Boolean;
      Contract_State  : in out Flow_State)
   is
   begin
      for Pair of Call.P_Call_Params loop
         if Include_Outputs
           or else not Formal_Is_Writable
             (Libadalang.Analysis.Param (Pair))
         then
            declare
               Key : constant Libadalang.Analysis.Ada_Node :=
                 Libadalang.Analysis.Ada_Node
                   (Libadalang.Analysis.Param (Pair));
            begin
               Flow_Set
                 (Contract_State, Key,
                  Integer_Value
                    (Libadalang.Analysis.Actual (Pair), Caller_State));
               Flow_Bool_Set
                 (Contract_State, Key,
                  Boolean_Value
                    (Libadalang.Analysis.Actual (Pair), Caller_State));
               Flow_Range_Set
                 (Contract_State, Key,
                  Range_Value
                    (Libadalang.Analysis.Actual (Pair), Caller_State));
            end;
         end if;
      end loop;
   exception
      when others =>
         null;
   end Seed_Formal_Values;

   procedure Check_Call_Precondition
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Call  : Libadalang.Analysis.Name'Class;
      State : Flow_State)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      if Config.Rule_States (Rules.Known_Precondition_Failure) /=
           Config.Enabled
        or else Libadalang.Analysis.Is_Null (Decl)
        or else not Effective_SPARK_Enabled (Decl)
      then
         return;
      end if;

      declare
         Pre : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Decl, "Pre");
         Contract_State : Flow_State := Empty_Flow_State;
      begin
         if Libadalang.Analysis.Is_Null (Pre) then
            return;
         end if;

         Seed_Formal_Values
           (Call, State, Include_Outputs => True,
            Contract_State => Contract_State);

         if Boolean_Value (Pre, Contract_State) = Bool_False then
            Report.Report_Rule_Violation
              (Unit, Call, Rules.Known_Precondition_Failure,
               "actual arguments make the precondition false");
         end if;
      end;
   end Check_Call_Precondition;

   --  Havocs every identifier anywhere under Node. Used for contract outputs
   --  and as the conservative fallback when formal/actual resolution fails.
   procedure Havoc_Identifiers_In
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier then
         Flow_Havoc (State, Flow_Referenced_Name (Node));
      end if;

      for I in 1 .. Node.Children_Count loop
         Havoc_Identifiers_In (Node.Child (I), State);
      end loop;
   end Havoc_Identifiers_In;

   --  Invalidates outputs named by a called subprogram's SPARK Global
   --  contract. Input and Proof_In associations are read-only and therefore
   --  preserve their abstract values. A malformed or unrecognized aggregate
   --  falls back to invalidating every identifier it contains.
   procedure Havoc_Global_Effects
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return;
      end if;

      declare
         Global : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Decl, "Global");
      begin
         if Libadalang.Analysis.Is_Null (Global) then
            return;
         elsif Global.Kind not in Libadalang.Common.Ada_Base_Aggregate
         then
            --  The shorthand form denotes inputs only.
            return;
         end if;

         for Item of Global.As_Base_Aggregate.F_Assocs loop
            if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
               declare
                  Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                    Item.As_Aggregate_Assoc;
                  Mode  : constant String :=
                    (if Assoc.F_Designators.Children_Count = 0 then ""
                     else Normalized_Text (Assoc.F_Designators.Child (1)));
               begin
                  if Mode = "output" or else Mode = "in-out" then
                     Havoc_Identifiers_In (Assoc.F_R_Expr, State);
                  elsif Mode /= "input" and then Mode /= "proof-in" then
                     Havoc_Identifiers_In (Global, State);
                     return;
                  end if;
               end;
            else
               Havoc_Identifiers_In (Global, State);
               return;
            end if;
         end loop;
      end;
   exception
      when others =>
         null;
   end Havoc_Global_Effects;

   procedure Havoc_Call_Actuals
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
   begin
      for Pair of Call.P_Call_Params loop
         if Formal_Is_Writable (Libadalang.Analysis.Param (Pair)) then
            Havoc_Identifiers_In
              (Libadalang.Analysis.Actual (Pair), State);
         end if;
      end loop;
   exception
      when others =>
         Havoc_Identifiers_In (Call, State);
   end Havoc_Call_Actuals;

   procedure Apply_Call_Postcondition
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      if Libadalang.Analysis.Is_Null (Decl)
        or else not Effective_SPARK_Enabled (Decl)
      then
         return;
      end if;

      declare
         Post : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Decl, "Post");
         Contract_State : Flow_State := Empty_Flow_State;
         True_State, False_State : Flow_State;
      begin
         if Libadalang.Analysis.Is_Null (Post) then
            return;
         end if;

         Seed_Formal_Values
           (Call, State, Include_Outputs => False,
            Contract_State => Contract_State);
         Narrow_By_Condition
           (Post, Contract_State, True_State, False_State);

         if Boolean_Value (Post, Contract_State) = Bool_False then
            return;
         end if;

         for Pair of Call.P_Call_Params loop
            if Formal_Is_Writable (Libadalang.Analysis.Param (Pair))
              and then Libadalang.Analysis.Actual (Pair).Kind =
                Libadalang.Common.Ada_Identifier
            then
               declare
                  Formal_Key : constant Libadalang.Analysis.Ada_Node :=
                    Libadalang.Analysis.Ada_Node
                      (Libadalang.Analysis.Param (Pair));
                  Actual_Key : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Referenced_Name
                      (Libadalang.Analysis.Actual (Pair));
                  Value : Abstract_Int :=
                    Flow_Lookup (True_State, Formal_Key);
                  Bounds : constant Abstract_Range :=
                    Flow_Range_Lookup (True_State, Formal_Key);
               begin
                  if not Value.Known
                    and then Bounds.Has_Low
                    and then Bounds.Has_High
                    and then Bounds.Low = Bounds.High
                  then
                     Value := Known_Int (Bounds.Low);
                  end if;

                  Flow_Set (State, Actual_Key, Value);
                  Flow_Bool_Set
                    (State, Actual_Key,
                     Flow_Bool_Lookup (True_State, Formal_Key));
                  Flow_Range_Set (State, Actual_Key, Bounds);
               end;
            end if;
         end loop;
      end;
   exception
      when others =>
         null;
   end Apply_Call_Postcondition;

   --  Invalidates whatever Node's own evaluation could change: writable
   --  actual parameters and Global outputs of calls found within it, and
   --  every variable directly assigned to when Node is a statement list
   --  containing assignments (the pre-loop-body havoc case). Does not
   --  descend into a nested subprogram body, which is analyzed separately.
   procedure Havoc_Effects_In
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Assign_Stmt =>
            Flow_Havoc (State, Flow_Assigned_Name (Node));

         when Libadalang.Common.Ada_Call_Expr =>
            Havoc_Global_Effects (Node.As_Call_Expr.F_Name, State);
            Havoc_Call_Actuals (Node.As_Call_Expr.F_Name, State);
            return;

         when Libadalang.Common.Ada_Subp_Body =>
            return;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         Havoc_Effects_In (Node.Child (I), State);
      end loop;
   end Havoc_Effects_In;

   --  Reports Division_By_Zero for every "/", "mod", or "rem" under Node
   --  whose right operand is only known to be zero once State's earlier
   --  assignments are taken into account (a plain literal zero is already
   --  caught by the node-local checks, so this only adds cases those
   --  would miss).
   procedure Scan_Expression_For_Flow_Bugs
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Config.Rule_States (Rules.Division_By_Zero) = Config.Enabled
        and then Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
      then
         declare
            Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
            Right : constant Abstract_Int :=
              Integer_Value (Expr.F_Right, State);
         begin
            if Expr.F_Op in Libadalang.Common.Ada_Op_Div
                | Libadalang.Common.Ada_Op_Mod
                | Libadalang.Common.Ada_Op_Rem
              and then not Is_Static_Zero (Expr.F_Right)
              and then Right.Known
              and then Right.Value = 0
            then
               Report.Report_Rule_Violation
                 (Unit, Expr.F_Right, Rules.Division_By_Zero,
                  "right operand is zero here based on an earlier " &
                    "assignment");
            end if;
         end;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Call_Expr then
         Check_Call_Precondition
           (Unit, Node.As_Call_Expr.F_Name, State);
      end if;

      for I in 1 .. Node.Children_Count loop
         Scan_Expression_For_Flow_Bugs (Unit, Node.Child (I), State);
      end loop;
   end Scan_Expression_For_Flow_Bugs;

   --  Reports Constant_Condition for Cond when State's earlier assignments
   --  resolve it to a known value that plain literal evaluation (no state)
   --  could not -- the literal-only case is already handled at the call
   --  site that also reports Non_Short_Circuit_Condition.
   procedure Check_Flow_Condition
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Cond  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State)
   is
   begin
      if Config.Rule_States (Rules.Constant_Condition) /= Config.Enabled
        or else Libadalang.Analysis.Is_Null (Cond)
        or else Boolean_Value (Cond) /= Bool_Unknown
      then
         return;
      end if;

      declare
         Flow_Value : constant Abstract_Bool := Boolean_Value (Cond, State);
      begin
         if Flow_Value /= Bool_Unknown then
            Report.Report_Rule_Violation
              (Unit, Cond, Rules.Constant_Condition,
               "condition is always " & Bool_Name (Flow_Value) &
                 " based on an earlier assignment");
         end if;
      end;
   end Check_Flow_Condition;

   --  Seeds State from every "Name : T := Default;" in Decls, when Default
   --  statically evaluates (possibly using State itself, so an earlier
   --  constant can feed a later one's initializer).
   procedure Seed_Declarations
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Decls : Libadalang.Analysis.Declarative_Part;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Decls) then
         return;
      end if;

      for I in 1 .. Decls.F_Decls.Children_Count loop
         declare
            Item : constant Libadalang.Analysis.Ada_Node :=
              Decls.F_Decls.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Item)
              and then Item.Kind = Libadalang.Common.Ada_Object_Decl
            then
               declare
                  Decl    : constant Libadalang.Analysis.Object_Decl :=
                    Item.As_Object_Decl;
                  Default : constant Libadalang.Analysis.Expr :=
                    Decl.F_Default_Expr;
               begin
                  if not Libadalang.Analysis.Is_Null (Default) then
                     Scan_Expression_For_Flow_Bugs (Unit, Default, State);

                     declare
                        Value      : constant Abstract_Int :=
                          Integer_Value (Default, State);
                        Bool_Value : constant Abstract_Bool :=
                          Boolean_Value (Default, State);
                     begin
                        for Id of Decl.F_Ids loop
                           if Value.Known then
                              Flow_Set
                                (State,
                                 Libadalang.Analysis.Ada_Node (Id), Value);
                           end if;

                           if Bool_Value /= Bool_Unknown then
                              Flow_Bool_Set
                                (State,
                                 Libadalang.Analysis.Ada_Node (Id),
                                 Bool_Value);
                           end if;
                        end loop;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Seed_Declarations;

   --  The outcome of interpreting a statement or statement list: the
   --  resulting Flow_State, and whether control can fall through to
   --  whatever follows (False once a return, raise, or unconditional exit
   --  has been seen).
   type Flow_Result is record
      State      : Flow_State;
      Terminated : Boolean;
   end record;

   --  Combines two branches reaching the same merge point. A branch that
   --  terminates contributes nothing to the merged state; if both do, the
   --  merge point itself is unreachable, which is reported by other checks,
   --  not this one -- Empty_Flow_State here is just an inert placeholder.
   function Join_Results (Left, Right : Flow_Result) return Flow_Result is
   begin
      if Left.Terminated and then Right.Terminated then
         return (State => Empty_Flow_State, Terminated => True);
      elsif Left.Terminated then
         return (State => Right.State, Terminated => False);
      elsif Right.Terminated then
         return (State => Left.State, Terminated => False);
      else
         return
           (State => Flow_Join (Left.State, Right.State),
            Terminated => False);
      end if;
   end Join_Results;

   --  Forward declaration: Interpret_Else_Chain, Interpret_If, and
   --  Interpret_Loop all call back into Interpret_Statements, which is
   --  defined after Interpret_Statement further below.
   function Interpret_Statements
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      List  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result;

   --  Interprets Stmt.F_Alternatives (I .. end) and Stmt.F_Else_Part as one
   --  chain of conditions, since each elsif is semantically nested inside
   --  the previous condition's negation. State already carries every prior
   --  condition's false-narrowing (from Interpret_If or an earlier level of
   --  this same chain), so a later elsif's own narrowing compounds on top.
   function Interpret_Else_Chain
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.If_Stmt;
      Index : Positive;
      State : Flow_State) return Flow_Result
   is
      Alternatives : constant Libadalang.Analysis.Elsif_Stmt_Part_List :=
        Stmt.F_Alternatives;
   begin
      if Index > Alternatives.Children_Count then
         if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
            return (State => State, Terminated => False);
         else
            return
              Interpret_Statements (Unit, Stmt.F_Else_Part.F_Stmts, State);
         end if;
      end if;

      declare
         Alt  : constant Libadalang.Analysis.Elsif_Stmt_Part :=
           Alternatives.Child (Index).As_Elsif_Stmt_Part;
         Cond : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
      begin
         Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
         Check_Flow_Condition (Unit, Cond, State);

         declare
            Cond_Value              : constant Abstract_Bool :=
              Boolean_Value (Cond, State);
            True_State, False_State : Flow_State;
         begin
            Narrow_By_Condition (Cond, State, True_State, False_State);

            if Cond_Value = Bool_True then
               return Interpret_Statements (Unit, Alt.F_Stmts, True_State);
            elsif Cond_Value = Bool_False then
               return
                 Interpret_Else_Chain (Unit, Stmt, Index + 1, False_State);
            else
               return Join_Results
                 (Interpret_Statements (Unit, Alt.F_Stmts, True_State),
                  Interpret_Else_Chain (Unit, Stmt, Index + 1, False_State));
            end if;
         end;
      end;
   end Interpret_Else_Chain;

   --  Interprets an if statement: picks the live branch when the condition
   --  resolves (via State) to a known value, otherwise interprets both
   --  branches from copies of the entering State (narrowed, where the
   --  condition has a recognizable shape, by Narrow_By_Condition) and joins
   --  the results.
   function Interpret_If
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.If_Stmt;
      State : Flow_State) return Flow_Result
   is
      Cond : constant Libadalang.Analysis.Expr := Stmt.F_Cond_Expr;
   begin
      Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
      Check_Flow_Condition (Unit, Cond, State);

      declare
         Cond_Value               : constant Abstract_Bool :=
           Boolean_Value (Cond, State);
         True_State, False_State  : Flow_State;
      begin
         Narrow_By_Condition (Cond, State, True_State, False_State);

         if Cond_Value = Bool_True then
            return Interpret_Statements (Unit, Stmt.F_Then_Stmts, True_State);
         elsif Cond_Value = Bool_False then
            return Interpret_Else_Chain (Unit, Stmt, 1, False_State);
         end if;

         return Join_Results
           (Interpret_Statements (Unit, Stmt.F_Then_Stmts, True_State),
            Interpret_Else_Chain (Unit, Stmt, 1, False_State));
      end;
   end Interpret_If;

   --  The Abstract_Range implied by a for-loop's iteration expression: the
   --  independently-known low/high bounds of a "Low .. High" range (the
   --  common shape for a numeric for loop). Anything else this pass
   --  doesn't specifically model (a subtype mark, a container iterator,
   --  an attribute reference, ...) yields Unknown_Range, which simply
   --  forgoes seeding the loop variable's range.
   function For_Loop_Range
     (Iter_Expr : Libadalang.Analysis.Ada_Node'Class;
      State     : Flow_State) return Abstract_Range
   is
   begin
      if Libadalang.Analysis.Is_Null (Iter_Expr)
        or else Iter_Expr.Kind /= Libadalang.Common.Ada_Bin_Op
        or else Iter_Expr.As_Bin_Op.F_Op /=
          Libadalang.Common.Ada_Op_Double_Dot
      then
         return Unknown_Range;
      end if;

      declare
         Low    : constant Abstract_Int :=
           Integer_Value (Iter_Expr.As_Bin_Op.F_Left, State);
         High   : constant Abstract_Int :=
           Integer_Value (Iter_Expr.As_Bin_Op.F_Right, State);
         Result : Abstract_Range;
      begin
         if Low.Known then
            Result.Has_Low := True;
            Result.Low := Low.Value;
         end if;

         if High.Known then
            Result.Has_High := True;
            Result.High := High.Value;
         end if;

         return Result;
      end;
   end For_Loop_Range;

   --  Interprets a loop: every variable assigned anywhere in the body (and
   --  every actual parameter of any call within it) is havoced before the
   --  body is interpreted once, since a later iteration could reach any
   --  point in the body with that variable already reassigned -- without
   --  this, a variable's pre-loop value would wrongly look like it still
   --  held after a reassignment later in the same loop body. The state
   --  after the loop is the join of "never entered" and "ran the body",
   --  since a while/for loop may execute zero times. A while loop's body is
   --  additionally entered from the condition's true-narrowing (still
   --  havoced afterward for anything the body itself reassigns), and a for
   --  loop's own control variable is seeded with its statically known
   --  range, when it has one.
   function Interpret_Loop
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
      Body_Stmts : constant Libadalang.Analysis.Stmt_List :=
        Stmt.As_Base_Loop_Stmt.F_Stmts;
      Havoced    : Flow_State := State;
   begin
      if Stmt.Kind = Libadalang.Common.Ada_While_Loop_Stmt then
         declare
            Spec : constant Libadalang.Analysis.Loop_Spec :=
              Stmt.As_While_Loop_Stmt.F_Spec;
         begin
            if not Libadalang.Analysis.Is_Null (Spec) then
               declare
                  Cond                     : constant Libadalang.Analysis.Expr
                    := Spec.As_While_Loop_Spec.F_Expr;
                  True_State, False_State  : Flow_State;
               begin
                  Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
                  Check_Flow_Condition (Unit, Cond, State);
                  Narrow_By_Condition (Cond, State, True_State, False_State);
                  Havoced := True_State;
               end;
            end if;
         end;
      end if;

      Havoc_Effects_In (Body_Stmts, Havoced);

      if Stmt.Kind = Libadalang.Common.Ada_For_Loop_Stmt then
         declare
            Spec : constant Libadalang.Analysis.For_Loop_Spec :=
              Stmt.As_For_Loop_Stmt.F_Spec.As_For_Loop_Spec;
         begin
            if Spec.F_Loop_Type.Kind = Libadalang.Common.Ada_Iter_Type_In then
               Flow_Range_Set
                 (Havoced,
                  Libadalang.Analysis.Ada_Node (Spec.F_Var_Decl.F_Id),
                  For_Loop_Range (Spec.F_Iter_Expr, State));
            end if;
         end;
      end if;

      declare
         Body_Result : constant Flow_Result :=
           Interpret_Statements (Unit, Body_Stmts, Havoced);
      begin
         return
           (State => Flow_Join (State, Body_Result.State),
            Terminated => False);
      end;
   end Interpret_Loop;

   --  True when Selector (already confirmed Known) is covered by one of
   --  Alt's choices, or Alt is the "when others" alternative. Ada requires
   --  "when others" to be the final alternative, so by the time it's
   --  reached here every earlier, numerically-resolvable alternative has
   --  already been checked and none matched.
   function Case_Alternative_Matches
     (Alt      : Libadalang.Analysis.Case_Stmt_Alternative;
      Selector : Abstract_Int;
      State    : Flow_State) return Boolean
   is
   begin
      for Choice of Alt.F_Choices loop
         if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
            return True;
         end if;

         declare
            Range_Value : constant Static_Interval :=
              Choice_Interval (Choice, State);
         begin
            if Range_Value.Known
              and then Selector.Value >= Range_Value.Low
              and then Selector.Value <= Range_Value.High
            then
               return True;
            end if;
         end;
      end loop;

      return False;
   end Case_Alternative_Matches;

   --  Interprets a case statement. When the selector's value is known from
   --  State, only the one alternative it statically matches is interpreted
   --  (mirroring how Interpret_If picks a single branch); a choice this
   --  pass can't resolve simply never matches, so an unresolvable choice
   --  only costs precision, never soundness, falling back to interpreting
   --  every alternative from a copy of the entering State and joining the
   --  results, the same way an if statement's branches are joined.
   function Interpret_Case
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Case_Stmt;
      State : Flow_State) return Flow_Result
   is
      Alternatives : constant Libadalang.Analysis.Case_Stmt_Alternative_List :=
        Stmt.F_Alternatives;
      Selector     : constant Abstract_Int :=
        Integer_Value (Stmt.F_Expr, State);
   begin
      Scan_Expression_For_Flow_Bugs (Unit, Stmt.F_Expr, State);

      if Selector.Known then
         for I in 1 .. Alternatives.Children_Count loop
            declare
               Alt : constant Libadalang.Analysis.Case_Stmt_Alternative :=
                 Alternatives.Child (I).As_Case_Stmt_Alternative;
            begin
               if Case_Alternative_Matches (Alt, Selector, State) then
                  return Interpret_Statements (Unit, Alt.F_Stmts, State);
               end if;
            end;
         end loop;
      end if;

      declare
         Result : Flow_Result := (State => State, Terminated => False);
         First  : Boolean := True;
      begin
         for I in 1 .. Alternatives.Children_Count loop
            declare
               Alt    : constant Libadalang.Analysis.Case_Stmt_Alternative :=
                 Alternatives.Child (I).As_Case_Stmt_Alternative;
               Branch : constant Flow_Result :=
                 Interpret_Statements (Unit, Alt.F_Stmts, State);
            begin
               if First then
                  Result := Branch;
                  First := False;
               else
                  Result := Join_Results (Result, Branch);
               end if;
            end;
         end loop;

         return Result;
      end;
   end Interpret_Case;

   --  Interprets a declare block: seeds its own local declarations'
   --  initializers into a copy of the entering State, then interprets its
   --  statements the same way a subprogram body's are (see
   --  Interpret_Subprogram_Flow). Skipped, the same conservative way, when
   --  the block has its own exception handlers.
   function Interpret_Decl_Block
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Block : Libadalang.Analysis.Decl_Block;
      State : Flow_State) return Flow_Result
   is
      Handled : constant Libadalang.Analysis.Handled_Stmts := Block.F_Stmts;
   begin
      if Libadalang.Analysis.Is_Null (Handled)
        or else Handled.F_Exceptions.Children_Count > 0
      then
         return (State => Empty_Flow_State, Terminated => False);
      end if;

      declare
         Seeded : Flow_State := State;
      begin
         Seed_Declarations (Unit, Block.F_Decls, Seeded);
         return Interpret_Statements (Unit, Handled.F_Stmts, Seeded);
      end;
   end Interpret_Decl_Block;

   --  Interprets one statement, threading State to the next. Anything not
   --  explicitly modeled here (select, accept, goto/label targets, ...)
   --  clears all tracked bindings rather than risk carrying a stale one
   --  across a construct this pass doesn't understand; Terminates_Statement
   --  still recognizes return/raise/goto/unconditional-exit so reachability
   --  past them is handled uniformly.
   function Interpret_Statement
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
   begin
      case Stmt.Kind is
         when Libadalang.Common.Ada_Assign_Stmt =>
            declare
               Assign : constant Libadalang.Analysis.Assign_Stmt :=
                 Stmt.As_Assign_Stmt;
               Next   : Flow_State := State;
            begin
               Scan_Expression_For_Flow_Bugs (Unit, Assign.F_Expr, State);
               Havoc_Effects_In (Assign.F_Dest, Next);
               Havoc_Effects_In (Assign.F_Expr, Next);

               declare
                  Target     : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Assigned_Name (Stmt);
                  Value      : constant Abstract_Int :=
                    Integer_Value (Assign.F_Expr, State);
                  Bool_Value : constant Abstract_Bool :=
                    Boolean_Value (Assign.F_Expr, State);
               begin
                  Flow_Set (Next, Target, Value);
                  Flow_Bool_Set (Next, Target, Bool_Value);
               end;

               return (State => Next, Terminated => False);
            end;

         when Libadalang.Common.Ada_Call_Stmt =>
            declare
               Next : Flow_State := State;
               Call : constant Libadalang.Analysis.Name :=
                 Stmt.As_Call_Stmt.F_Call;
            begin
               Check_Call_Precondition (Unit, Call, State);
               Havoc_Global_Effects (Call, Next);
               Havoc_Call_Actuals (Call, Next);
               Apply_Call_Postcondition (Call, Next);
               return (State => Next, Terminated => False);
            end;

         when Libadalang.Common.Ada_If_Stmt =>
            return Interpret_If (Unit, Stmt.As_If_Stmt, State);

         when Libadalang.Common.Ada_Case_Stmt =>
            return Interpret_Case (Unit, Stmt.As_Case_Stmt, State);

         when Libadalang.Common.Ada_Decl_Block =>
            return Interpret_Decl_Block (Unit, Stmt.As_Decl_Block, State);

         when Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            return Interpret_Loop (Unit, Stmt, State);

         when Libadalang.Common.Ada_Null_Stmt
            | Libadalang.Common.Ada_Label
            | Libadalang.Common.Ada_Pragma_Node =>
            return (State => State, Terminated => False);

         when Libadalang.Common.Ada_Exit_Stmt =>
            declare
               Cond : constant Libadalang.Analysis.Expr :=
                 Stmt.As_Exit_Stmt.F_Cond_Expr;
            begin
               if Libadalang.Analysis.Is_Null (Cond) then
                  return (State => State, Terminated => True);
               end if;

               Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
               Check_Flow_Condition (Unit, Cond, State);
               return (State => State, Terminated => False);
            end;

         when others =>
            if Ada_Text.Terminates_Statement (Stmt) then
               return (State => State, Terminated => True);
            else
               return (State => Empty_Flow_State, Terminated => False);
            end if;
      end case;
   end Interpret_Statement;

   function Interpret_Statements
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      List  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
      Current : Flow_State := State;
   begin
      if Libadalang.Analysis.Is_Null (List) then
         return (State => Current, Terminated => False);
      end if;

      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Stmt) then
               declare
                  Step : constant Flow_Result :=
                    Interpret_Statement (Unit, Stmt, Current);
               begin
                  Current := Step.State;
                  if Step.Terminated then
                     return (State => Current, Terminated => True);
                  end if;
               end;
            end if;
         end;
      end loop;

      return (State => Current, Terminated => False);
   end Interpret_Statements;

   procedure Interpret_Subprogram_Flow
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Handled : constant Libadalang.Analysis.Handled_Stmts :=
        Subprogram.F_Stmts;
   begin
      if (Config.Rule_States (Rules.Division_By_Zero) /= Config.Enabled
          and then Config.Rule_States (Rules.Constant_Condition) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Precondition_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Postcondition_Failure) /=
            Config.Enabled)
        or else Libadalang.Analysis.Is_Null (Handled)
        or else Handled.F_Exceptions.Children_Count > 0
      then
         return;
      end if;

      declare
         State  : Flow_State := Empty_Flow_State;
         Result : Flow_Result;
         Pre    : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Subprogram, "Pre");
         Post   : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Subprogram, "Post");
      begin
         Seed_Declarations (Unit, Subprogram.F_Decls, State);

         if not Libadalang.Analysis.Is_Null (Pre) then
            declare
               True_State, False_State : Flow_State;
            begin
               Scan_Expression_For_Flow_Bugs (Unit, Pre, State);
               Narrow_By_Condition (Pre, State, True_State, False_State);
               State := True_State;
            end;
         end if;

         Result := Interpret_Statements (Unit, Handled.F_Stmts, State);

         if not Libadalang.Analysis.Is_Null (Post) then
            Scan_Expression_For_Flow_Bugs (Unit, Post, Result.State);

            if Config.Rule_States (Rules.Known_Postcondition_Failure) =
                 Config.Enabled
              and then Effective_SPARK_Enabled (Subprogram)
              and then Boolean_Value (Post, Result.State) = Bool_False
            then
               Report.Report_Rule_Violation
                 (Unit, Post, Rules.Known_Postcondition_Failure,
                  "subprogram body makes the postcondition false");
            end if;
         end if;
      end;
   end Interpret_Subprogram_Flow;

end Adalang_Analyzer.Flow_Interp;
