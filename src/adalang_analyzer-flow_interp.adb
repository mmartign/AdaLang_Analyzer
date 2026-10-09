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
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Unbounded;

with GNATCOLL.GMP.Integers;

with Libadalang.Common;
with Langkit_Support.Slocs;
with Langkit_Support.Text;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Control_Flow_Graph;
with Adalang_Analyzer.Flow_Domain; use Adalang_Analyzer.Flow_Domain;
with Adalang_Analyzer.Flow_Contracts;
with Adalang_Analyzer.Flow_Eval;   use Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Project_Files;
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;
with Adalang_Analyzer.SPARK_Readiness;
with Adalang_Analyzer.Subprogram_Summaries;
with Adalang_Analyzer.Text_Utils;
with Adalang_Analyzer.VC_Prover;

package body Adalang_Analyzer.Flow_Interp is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;
   use type Rules.Rule_Kind;

   package Proof renames Adalang_Analyzer.Proof_Obligations;
   package VC renames Adalang_Analyzer.VC_Prover;
   use type Proof.Analysis_Method;
   use type VC.VC_Result;

   --  How far Verify_Subprogram follows calls into callee bodies when it
   --  asks whether a function called in an expression may change state.
   Max_Effect_Depth : constant := 4;

   --  What Verify_Subprogram has already worked out about callee bodies in
   --  the unit being verified: for a callee declaration at a given depth,
   --  whether its body may change state. The answer does not depend on the
   --  caller, and without it each call site walks the callee's whole call
   --  tree again, which grows with the fourth power of the calls per body.
   package Body_Effect_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Libadalang.Analysis.Ada_Node,
      Element_Type    => Boolean,
      Hash            => Libadalang.Analysis.Hash,
      Equivalent_Keys => Libadalang.Analysis."=");
   Body_Effects :
     array (Natural range 0 .. Max_Effect_Depth) of Body_Effect_Maps.Map;

   --  The function calls evaluated in the subprogram being verified that
   --  may change state, by their names, each with how far what it writes
   --  can reach: the objects declared outside that subprogram, or any
   --  object. The state a node is entered with has their effects already,
   --  but a fact the node's own condition establishes does not: the call
   --  may come after the test that establishes it (FP-109).
   type Effect_Reach is (Outside_Subprogram, Anywhere);
   package Effect_Reach_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Libadalang.Analysis.Ada_Node,
      Element_Type    => Effect_Reach,
      Hash            => Libadalang.Analysis.Hash,
      Equivalent_Keys => Libadalang.Analysis."=");
   Effectful_Call_Reach : Effect_Reach_Maps.Map;
   Verified_Subprogram  : Libadalang.Analysis.Ada_Node :=
     Libadalang.Analysis.No_Ada_Node;

   --  True when Node lies within the subprogram being verified.
   function Inside_Verified_Subprogram
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Node);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current = Verified_Subprogram then
            return True;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Inside_Verified_Subprogram;

   --  Found when Node evaluates one of those calls, with the farthest
   --  reach of those it does.
   procedure Find_Evaluated_Effects
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Found : in out Boolean;
      Reach : in out Effect_Reach)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) or else Effectful_Call_Reach.Is_Empty
      then
         return;
      end if;

      declare
         Position : constant Effect_Reach_Maps.Cursor :=
           Effectful_Call_Reach.Find (Libadalang.Analysis.Ada_Node (Node));
      begin
         if Effect_Reach_Maps.Has_Element (Position) then
            Found := True;
            Reach :=
              Effect_Reach'Max (Reach, Effect_Reach_Maps.Element (Position));
         end if;
      end;
      for Index in 1 .. Node.Children_Count loop
         Find_Evaluated_Effects (Node.Child (Index), Found, Reach);
      end loop;
   end Find_Evaluated_Effects;

   function Evaluates_Effectful_Call
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Found : Boolean := False;
      Reach : Effect_Reach := Outside_Subprogram;
   begin
      Find_Evaluated_Effects (Node, Found, Reach);
      return Found;
   exception
      when others =>
         return True;
   end Evaluates_Effectful_Call;

   --  Removes from State what the state-changing calls Cond evaluates may
   --  have written by the time Cond has its value.
   procedure Forget_Evaluated_Effects
     (Cond  : Libadalang.Analysis.Ada_Node'Class;
      State : in out Flow_State)
   is
      Found : Boolean := False;
      Reach : Effect_Reach := Outside_Subprogram;
   begin
      Find_Evaluated_Effects (Cond, Found, Reach);
      if not Found then
         return;
      elsif Reach = Anywhere
        or else Libadalang.Analysis.Is_Null (Verified_Subprogram)
      then
         Flow_Forget_All_Values (State);
         return;
      end if;

      declare
         Keys : array (1 .. Binding_Count (State)) of
           Libadalang.Analysis.Ada_Node;
      begin
         for Index in Keys'Range loop
            Keys (Index) := Binding_At (State, Index).Decl;
         end loop;
         for Key of Keys loop
            if not Inside_Verified_Subprogram (Key) then
               Flow_Forget_Value (State, Key);
            end if;
         end loop;
      end;
   exception
      when others =>
         Flow_Forget_All_Values (State);
   end Forget_Evaluated_Effects;

   --  As Flow_Eval.Narrow_By_Condition, which this hides, less what a
   --  state-changing call in Cond leaves unknown (FP-109). The profile is
   --  that of the procedure it hides.
   procedure Narrow_By_Condition
     (Cond        : Libadalang.Analysis.Ada_Node'Class;
      State       : Flow_State;
      True_State  : out Flow_State;
      False_State : out Flow_State)  --  adalang-analyzer: ignore Swappable_Parameters
   is
   begin
      Adalang_Analyzer.Flow_Eval.Narrow_By_Condition
        (Cond, State, True_State, False_State);
      Forget_Evaluated_Effects (Cond, True_State);
      Forget_Evaluated_Effects (Cond, False_State);
   end Narrow_By_Condition;

   --  The function calls evaluated in the subprogram being verified that
   --  are not taken to leave everything as it is: anything but a literal,
   --  a predefined operation and a function under an explicit SPARK_Mode.
   --  A function found to change no object by name may still write through
   --  an access value it is given, which changes the value of whatever
   --  holds that access value.
   package Call_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Libadalang.Analysis.Ada_Node,
      Hash                => Libadalang.Analysis.Hash,
      Equivalent_Elements => Libadalang.Analysis."=",
      "="                 => Libadalang.Analysis."=");
   Untrusted_Calls : Call_Sets.Set;

   function Evaluates_Untrusted_Call
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) or else Untrusted_Calls.Is_Empty
      then
         return False;
      elsif Untrusted_Calls.Contains (Libadalang.Analysis.Ada_Node (Node))
      then
         return True;
      end if;
      for Index in 1 .. Node.Children_Count loop
         if Evaluates_Untrusted_Call (Node.Child (Index)) then
            return True;
         end if;
      end loop;
      return False;
   exception
      when others =>
         return True;
   end Evaluates_Untrusted_Call;

   --  As VC.Assume. A condition that evaluates a state-changing call is
   --  no fact about what holds once it has been evaluated, and leaves
   --  none standing either; one that evaluates a call not taken to leave
   --  everything as it is leaves none about a value that is not a scalar.
   function Assume_Condition
     (Symbols   : VC.Symbolic_State;
      Condition : Libadalang.Analysis.Expr;
      Truth     : Boolean;
      Flow      : Flow_State) return VC.Symbolic_State
   is
     (if Evaluates_Effectful_Call (Condition) then VC.Havoc
      elsif Evaluates_Untrusted_Call (Condition)
      then VC.Forget_Composite_Values
             (VC.Assume (Symbols, Condition, Truth => Truth, Flow => Flow),
              Condition)
      else VC.Assume (Symbols, Condition, Truth => Truth, Flow => Flow));

   --  Symbols with Condition assumed in it. Where Condition gives the
   --  translation nothing, Symbols keeps what it had, unless a call in
   --  Condition makes that stale.
   procedure Assume_Into
     (Symbols   : in out VC.Symbolic_State;
      Condition : Libadalang.Analysis.Expr;
      Truth     : Boolean;
      Flow      : Flow_State)
   is
      Updated : constant VC.Symbolic_State :=
        VC.Assume (Symbols, Condition, Truth => Truth, Flow => Flow);
   begin
      if Evaluates_Effectful_Call (Condition) then
         Symbols := VC.Havoc;
         return;
      end if;
      --  VC.Assume gives VC.Havoc, a wholly empty state, for a condition
      --  it can take nothing from. Adopting that would discard what was
      --  assumed before -- a loop's other leading invariants, the guards
      --  met so far -- for the sake of one condition that merely
      --  contributes nothing.
      if not VC.Equal (Updated, VC.Havoc) then
         Symbols := Updated;
      end if;
      if Evaluates_Untrusted_Call (Condition) then
         Symbols := VC.Forget_Composite_Values (Symbols, Condition);
      end if;
   end Assume_Into;

   --  True while Verify_Subprogram's fixed-point run is still iterating. A
   --  state seen then is one some path reaches, not yet the join of all of
   --  them, so what it shows to be certain may not be: a divisor that is
   --  zero before a loop has run need not be zero after it. Rule findings
   --  are therefore reported only from converged states, when
   --  Finalize_Node replays each determination.
   Fixpoint_In_Progress : Boolean := False;

   procedure Record_Outcome
     (Unit           : Libadalang.Analysis.Analysis_Unit;
      Node           : Libadalang.Analysis.Ada_Node'Class;
      Kind           : Proof.Obligation_Kind;
      Status         : Proof.Obligation_Status;
      Method         : Proof.Analysis_Method;
      Explanation    : String;
      Abstract_State : String := "";
      Imprecision    : String := "";
      Reason_Code    : String := "";
      Blocking_Expression : String := "";
      Inline_Path    : String := "";
      Final          : Boolean := False) is
   begin
      Proof.Register_At
        (Unit             => Unit,
         Node             => Node,
         Kind             => Kind,
         Status           => Status,
         Method           => Method,
         Abstract_State   => Abstract_State,
         Explanation      => Explanation,
         Imprecision_Source => Imprecision,
         Reason_Code      => Reason_Code,
         Blocking_Expression => Blocking_Expression,
         Inline_Path      => Inline_Path,
         Configuration_Id => Config.Assurance_Profile_Name,
         Final            => Final);
   end Record_Outcome;

   procedure Record_Definite_Error
     (Unit           : Libadalang.Analysis.Analysis_Unit;
      Node           : Libadalang.Analysis.Ada_Node'Class;
      Kind           : Proof.Obligation_Kind;
      Method         : Proof.Analysis_Method;
      Explanation    : String;
      Abstract_State : String := "";
      Final          : Boolean := False) is
   begin
      --  Nor is an obligation a definite error on the showing of a state
      --  that has not settled. Finalize_Node records what the converged
      --  state says of it; until then it is undecided, so that a proof of
      --  it from another such state is not taken for a contradiction, for
      --  which the whole subprogram would be given up.
      if Fixpoint_In_Progress and then not Final then
         Record_Outcome
           (Unit, Node, Kind, Proof.Unproved, Method,
            "not decided before the fixed point has converged",
            Abstract_State);
         return;
      end if;

      Record_Outcome
        (Unit, Node, Kind, Proof.Definite_Error, Method, Explanation,
         Abstract_State, Final => Final);
   end Record_Definite_Error;

   procedure Record_Unproved
     (Unit           : Libadalang.Analysis.Analysis_Unit;
      Node           : Libadalang.Analysis.Ada_Node'Class;
      Kind           : Proof.Obligation_Kind;
      Method         : Proof.Analysis_Method;
      Explanation    : String;
      Abstract_State : String := "";
      Imprecision    : String := "";
      Reason_Code    : String := "";
      Blocking_Expression : String := "";
      Inline_Path    : String := "";
      Final          : Boolean := False) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Unproved, Method, Explanation,
         Abstract_State, Imprecision, Reason_Code, Blocking_Expression,
         Inline_Path, Final => Final);
   end Record_Unproved;

   procedure Record_VC_Unproved
     (Unit                  : Libadalang.Analysis.Analysis_Unit;
      Node                  : Libadalang.Analysis.Ada_Node'Class;
      Kind                  : Proof.Obligation_Kind;
      Method                : Proof.Analysis_Method;
      Explanation           : String;
      Default_Imprecision   : String;
      Outcome               : VC.VC_Outcome;
      Final                 : Boolean := False) is
   begin
      Record_Unproved
        (Unit, Node, Kind, Method, Explanation,
         Imprecision =>
           (if Outcome.Result = VC.VC_Unavailable
            then "CVC5/Z3 prover portfolio is unavailable"
            elsif Outcome.Result = VC.VC_Unsupported
            then VC.Unsupported_Description (Outcome)
            else Default_Imprecision),
         Reason_Code =>
           (if Outcome.Result = VC.VC_Unsupported
            then VC.Unsupported_Reason_Code (Outcome) else ""),
         Blocking_Expression =>
           (if Outcome.Result = VC.VC_Unsupported
            then VC.Blocking_Expression (Outcome) else ""),
         Inline_Path =>
           (if Outcome.Result = VC.VC_Unsupported
            then VC.Inline_Path (Outcome) else ""),
         Final => Final);
   end Record_VC_Unproved;

   procedure Record_Proved_Safe
     (Unit           : Libadalang.Analysis.Analysis_Unit;
      Node           : Libadalang.Analysis.Ada_Node'Class;
      Kind           : Proof.Obligation_Kind;
      Method         : Proof.Analysis_Method;
      Explanation    : String;
      Abstract_State : String := "";
      Final          : Boolean := False) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Proved_Safe, Method, Explanation,
         Abstract_State, Final => Final);
   end Record_Proved_Safe;

   --  Records the read Node of the object Key as safe where it is what
   --  always holds of Key that says it is initialized, and not State: a
   --  constant, an "in" parameter or the parameter of a loop holds a value
   --  wherever it is read. Recorded is False where State says so itself,
   --  or nothing does, and nothing is recorded then.
   procedure Record_Standing_Value
     (Unit     : Libadalang.Analysis.Analysis_Unit;
      Node     : Libadalang.Analysis.Ada_Node'Class;
      Key      : Libadalang.Analysis.Ada_Node;
      State    : Flow_State;
      Final    : Boolean;
      Recorded : out Boolean) is
   begin
      Recorded :=
        Stored_Initialization (State, Key) /= Bool_True
        and then Flow_Initialization (State, Key) = Bool_True;
      if Recorded then
         --  proof-path: initialization-standing
         Record_Proved_Safe
           (Unit, Node, Proof.Initialization_Check, Proof.Static_Evaluation,
            "object holds a value wherever it is read",
            "a constant, an in parameter or a loop parameter",
            Final => Final);
      end if;
   end Record_Standing_Value;

   procedure Record_Unreachable
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Node        : Libadalang.Analysis.Ada_Node'Class;
      Kind        : Proof.Obligation_Kind;
      Explanation : String) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Unreachable, Proof.Flow_Analysis,
         Explanation);
   end Record_Unreachable;

   procedure Record_Unsupported
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Node        : Libadalang.Analysis.Ada_Node'Class;
      Kind        : Proof.Obligation_Kind;
      Explanation : String) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Unsupported, Proof.No_Analysis,
         Explanation, Imprecision => "outside bounded verification subset");
   end Record_Unsupported;

   procedure Report_Flow_Violation
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Node        : Libadalang.Analysis.Ada_Node'Class;
      Rule        : Rules.Rule_Kind;
      Message     : String;
      Explanation : String := "";  --  adalang-analyzer: ignore Swappable_Parameters
      Evidence    : String := "") is  --  adalang-analyzer: ignore Swappable_Parameters
   begin
      if not Fixpoint_In_Progress then
         Report.Report_Rule_Violation
           (Unit, Node, Rule, Message, Explanation, Evidence);
      end if;
   end Report_Flow_Violation;

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
      elsif Libadalang.Analysis.Is_Null (Result)
        and then Decl.Kind in Libadalang.Common.Ada_Null_Subp_Decl
                            | Libadalang.Common.Ada_Expr_Function
      then
         --  A null procedure or expression function that completes an
         --  earlier declaration: the contract is on that declaration. Only
         --  a precise resolution counts, so a same-name overload's contract
         --  is never picked up.
         declare
            Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
              Decl.As_Base_Subp_Body.P_Decl_Part;
         begin
            if not Libadalang.Analysis.Is_Null (Decl_Part)
              and then Libadalang.Analysis.Ada_Node (Decl_Part) /=
                Libadalang.Analysis.Ada_Node (Decl)
            then
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

   --  The earlier declaration a completion's contracts are written on,
   --  resolved the way Contract_Expression resolves it; No_Basic_Decl when
   --  Decl is not a completion or has no separate declaration.
   function Contract_Part
     (Decl : Libadalang.Analysis.Basic_Decl'Class)
      return Libadalang.Analysis.Basic_Decl
   is
      Part : Libadalang.Analysis.Basic_Decl :=
        Libadalang.Analysis.No_Basic_Decl;
   begin
      if Decl.Kind = Libadalang.Common.Ada_Subp_Body then
         Part := Decl.As_Subp_Body.P_Decl_Part (Imprecise_Fallback => True);
      elsif Decl.Kind in Libadalang.Common.Ada_Null_Subp_Decl
                       | Libadalang.Common.Ada_Expr_Function
      then
         Part := Decl.As_Base_Subp_Body.P_Decl_Part;
      end if;

      if Libadalang.Analysis.Is_Null (Part)
        or else Libadalang.Analysis.Ada_Node (Part) =
          Libadalang.Analysis.Ada_Node (Decl)
      then
         return Libadalang.Analysis.No_Basic_Decl;
      end if;
      return Part;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Contract_Part;

   --  The defining name of the formal of Subprogram spelled Name (in
   --  normalized form), or No_Ada_Node.
   function Formal_Named
     (Subprogram : Libadalang.Analysis.Basic_Decl;
      Name       : String) return Libadalang.Analysis.Ada_Node
   is
   begin
      for Param of Subprogram.P_Subp_Spec_Or_Null.P_Params loop
         for Id of Param.F_Ids loop
            if Text_Utils.Normalize_Rule_Name (Ada_Text.Node_Text (Id)) = Name
            then
               return Libadalang.Analysis.Ada_Node (Id);
            end if;
         end loop;
      end loop;
      return Libadalang.Analysis.No_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Formal_Named;

   function Has_Aspect
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Boolean
   is
      Aspect : Libadalang.Analysis.Aspect;
   begin
      Aspect := Decl.P_Get_Aspect
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Name)));
      if Libadalang.Analysis.Exists (Aspect) then
         return True;
      elsif Decl.Kind = Libadalang.Common.Ada_Subp_Body then
         declare
            Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
              Decl.As_Subp_Body.P_Decl_Part
                (Imprecise_Fallback => True);
         begin
            return not Libadalang.Analysis.Is_Null (Decl_Part)
              and then Has_Aspect (Decl_Part, Name);
         end;
      end if;
      return False;
   exception
      when others =>
         return False;
   end Has_Aspect;

   --  The defining name an identifier resolves to, or No_Ada_Node for
   --  anything else. The Flow_State key type; kept distinct from a
   --  Basic_Decl resolution, which cannot tell apart two names introduced
   --  by one multi-name declaration.
   function Flow_Referenced_Name
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Libadalang.Analysis.No_Ada_Node;
      elsif Node.Kind = Libadalang.Common.Ada_Dotted_Name then
         --  An expanded name denotes the same object as its last
         --  identifier (FP-097).
         return Flow_Referenced_Name (Expanded_Name_Target (Node));
      elsif Node.Kind /= Libadalang.Common.Ada_Identifier then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Flow_Referenced_Name;

   --  Determine the initialization state of an object declaration that has
   --  no explicit default expression. A renaming denotes an existing object,
   --  so a simple renaming inherits that object's state. For a newly declared
   --  object, only a resolved scalar type justifies the strong conclusion
   --  that a subsequent read is definitely uninitialized. Other types may
   --  have language-defined or type-defined initialization; keep those
   --  unknown unless a more precise model establishes their state.
   function Implicit_Initialization
     (Decl  : Libadalang.Analysis.Object_Decl;
      State : Flow_State) return Abstract_Bool
   is
      Clause : constant Libadalang.Analysis.Renaming_Clause :=
        Decl.F_Renaming_Clause;
   begin
      if not Libadalang.Analysis.Is_Null (Clause) then
         declare
            Renamed : constant Libadalang.Analysis.Ada_Node :=
              Flow_Referenced_Name (Clause.F_Renamed_Object);
         begin
            if Libadalang.Analysis.Is_Null (Renamed) then
               return Bool_Unknown;
            end if;
            return Flow_Initialization (State, Renamed);
         end;
      end if;

      --  An address clause overlays storage whose validity this local flow
      --  model cannot infer. In particular, a scalar view may denote bytes
      --  that were initialized through another object, so it is not sound to
      --  call the view definitely uninitialized.
      if Has_Aspect (Decl, "Address") then
         return Bool_Unknown;
      end if;

      declare
         Type_Expr : constant Libadalang.Analysis.Type_Expr :=
           Decl.F_Type_Expr;
      begin
         if Libadalang.Analysis.Is_Null (Type_Expr) then
            return Bool_Unknown;
         end if;

         declare
            Base : constant Libadalang.Analysis.Base_Type_Decl :=
              Type_Expr.P_Designated_Type_Decl;
         begin
            if not Libadalang.Analysis.Is_Null (Base)
              and then Base.P_Is_Scalar_Type
            then
               return Bool_False;
            end if;
         end;
      end;

      return Bool_Unknown;
   exception
      when others =>
         return Bool_Unknown;
   end Implicit_Initialization;

   --  On entry, an out parameter is not uniformly equivalent to a fresh
   --  scalar object. Scalar out parameters have no value; composite and
   --  private types can have default-initialized parts or other semantics
   --  that this bounded model does not resolve. Preserve the strong error
   --  result only for a known scalar type.
   function Output_Parameter_Initialization
     (Param : Libadalang.Analysis.Param_Spec) return Abstract_Bool
   is
      Type_Expr : constant Libadalang.Analysis.Type_Expr := Param.F_Type_Expr;
   begin
      if Libadalang.Analysis.Is_Null (Type_Expr) then
         return Bool_Unknown;
      end if;

      declare
         Base : constant Libadalang.Analysis.Base_Type_Decl :=
           Type_Expr.P_Designated_Type_Decl;
      begin
         if not Libadalang.Analysis.Is_Null (Base)
           and then Base.P_Is_Scalar_Type
         then
            return Bool_False;
         end if;
      end;

      return Bool_Unknown;
   exception
      when others =>
         return Bool_Unknown;
   end Output_Parameter_Initialization;

   --  True when evaluating an identifier requires its stored value. Bounds,
   --  representation, address, and access attributes inspect an object's
   --  subtype or identity rather than reading that value. Likewise, the base
   --  name of an assignment target is written, although index expressions in
   --  that target are still reads and therefore are not excluded here.
   function Initialization_Read_Required
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Node);

      function Is_Nonvalue_Attribute
        (Prefix : Libadalang.Analysis.Ada_Node) return Boolean
      is
         Parent : constant Libadalang.Analysis.Ada_Node := Prefix.Parent;
      begin
         if Parent.Kind /= Libadalang.Common.Ada_Attribute_Ref
           or else Libadalang.Analysis.Ada_Node
             (Parent.As_Attribute_Ref.F_Prefix) /= Prefix
         then
            return False;
         end if;

         declare
            Attribute_Name : constant String :=
              Text_Utils.Normalize_Rule_Name
                (Ada_Text.Node_Text (Parent.As_Attribute_Ref.F_Attribute));
         begin
            return Attribute_Name in
              "access" | "address" | "alignment" | "component-size"
                | "first" | "last" | "length" | "object-size" | "range"
                | "size" | "unchecked-access" | "unrestricted-access"
                | "value-size";
         end;
      exception
         when others =>
            return False;
      end Is_Nonvalue_Attribute;
   begin
      if Libadalang.Analysis.Is_Null (Current)
        or else Current.Kind /= Libadalang.Common.Ada_Identifier
      then
         return True;
      end if;

      --  A pragma argument naming an entity ("Status" in "pragma
      --  Unreferenced (Status);") is never read at runtime: it merely
      --  names the declaration without inspecting its value, the same
      --  reasoning Checks.Data_Flow's Uninitialized_Read walk already
      --  applies to this exact node shape. Without this guard, the
      --  climbing loop below falls through its assignment-target/prefix
      --  cases to "return True", misreading the pragma argument as a
      --  definite read before the object's real first assignment.
      --  Observed in the wild (gnatcoll-core's GNATCOLL.OS.FS.Close and
      --  GNATCOLL.Plugins.Unload): "Status : int; pragma Unreferenced
      --  (Status); begin Status := C_Close (FD); end;" flagged as a
      --  definite initialization error at the pragma, two statements
      --  before the assignment that actually initializes Status.
      if Current.Parent.Kind = Libadalang.Common.Ada_Pragma_Argument_Assoc
        and then not Libadalang.Analysis.Is_Null (Current.Parent.Parent)
        and then not Libadalang.Analysis.Is_Null
          (Current.Parent.Parent.Parent)
        and then Current.Parent.Parent.Parent.Kind =
          Libadalang.Common.Ada_Pragma_Node
      then
         declare
            Pragma_Name : constant String :=
              Text_Utils.Normalize_Rule_Name
                (Ada_Text.Node_Text
                   (Current.Parent.Parent.Parent.As_Pragma_Node.F_Id));
         begin
            if Pragma_Name = "unreferenced"
              or else Pragma_Name = "unmodified"
              or else Pragma_Name = "warnings"
            then
               return False;
            end if;
         end;
      end if;

      loop
         if Is_Nonvalue_Attribute (Current) then
            return False;
         end if;

         declare
            Parent : constant Libadalang.Analysis.Ada_Node := Current.Parent;
         begin
            if Libadalang.Analysis.Is_Null (Parent) then
               return True;
            elsif Parent.Kind = Libadalang.Common.Ada_Assign_Stmt
              and then Libadalang.Analysis.Ada_Node
                (Parent.As_Assign_Stmt.F_Dest) = Current
            then
               return False;
            elsif
              (Parent.Kind = Libadalang.Common.Ada_Dotted_Name
               and then Libadalang.Analysis.Ada_Node
                 (Parent.As_Dotted_Name.F_Prefix) = Current)
              or else
                --  The suffix climbs exactly like the prefix: naming a
                --  Dotted_Name's suffix is no more a read of its value
                --  than naming the prefix is, and judgment defers to the
                --  Dotted_Name's own outer context either way. Harmless
                --  for an ordinary "R.Field" (Field resolves to a
                --  Component_Decl, never Tracked below, so this arm
                --  never changes the outcome), but required for
                --  "Subp_Name.Param := ...;" inside "procedure Subp_Name
                --  (Param : out ...)" (RM 8.3 unit-name qualification,
                --  the same shape FP-011 fixed for
                --  SPARK_Readiness.Same_Parameter): without this arm,
                --  Param -- the suffix -- had no climbable case at all
                --  and fell straight to "return True" below, misreading
                --  its own qualified write as a read of an
                --  uninitialized out parameter (FP-046).
                (Parent.Kind = Libadalang.Common.Ada_Dotted_Name
                 and then Libadalang.Analysis.Ada_Node
                   (Parent.As_Dotted_Name.F_Suffix) = Current)
              or else
                (Parent.Kind = Libadalang.Common.Ada_Call_Expr
                 and then Libadalang.Analysis.Ada_Node
                   (Parent.As_Call_Expr.F_Name) = Current)
              or else
                (Parent.Kind = Libadalang.Common.Ada_Explicit_Deref
                 and then Libadalang.Analysis.Ada_Node
                   (Parent.As_Explicit_Deref.F_Prefix) = Current)
            then
               Current := Parent;
            else
               return True;
            end if;
         end;
      end loop;
   exception
      when others =>
         return True;
   end Initialization_Read_Required;

   --  The nearest enclosing Subp_Body containing Node, i.e. the
   --  subprogram whose own defining name a nested statement can use to
   --  prefix-qualify one of its own formal parameters (Ada's general
   --  unit-name qualification, RM 8.3), typically to reach a parameter
   --  that a same-named component of an enclosing protected or task
   --  object would otherwise shadow for simple-name visibility.
   --  No_Basic_Decl if Node isn't nested in one. Entry_Body is
   --  deliberately not recognized here, unlike SPARK_Readiness's own
   --  Enclosing_Subprogram_Or_Entry: Interpret_Subprogram_Flow (the only
   --  caller reaching this, transitively, through Flow_Assigned_Name)
   --  only ever descends into Subp_Body, so an entry can never be Node's
   --  innermost enclosing construct here.
   function Enclosing_Subp_Body_Decl
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl
   is
      Current : Libadalang.Analysis.Ada_Node := Libadalang.Analysis.Ada_Node
        (Node);
   begin
      loop
         if Libadalang.Analysis.Is_Null (Current) then
            return Libadalang.Analysis.No_Basic_Decl;
         elsif Current.Kind = Libadalang.Common.Ada_Subp_Body then
            return Current.As_Basic_Decl;
         end if;
         Current := Current.Parent;
      end loop;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Enclosing_Subp_Body_Decl;

   --  The Defining_Name of Subprogram's own formal parameter named
   --  Suffix_Name, or No_Ada_Node if it has none by that name. This is
   --  the very same Defining_Name node Seed_Parameters uses as the
   --  parameter's Flow_State key, so returning it here lets a write
   --  through an own-name-qualified reference update the same binding a
   --  plain reference to the parameter would.
   function Matching_Formal_Name
     (Subprogram  : Libadalang.Analysis.Basic_Decl;
      Suffix_Name : String) return Libadalang.Analysis.Ada_Node
   is
   begin
      for Param of Subprogram.As_Subp_Body.F_Subp_Spec.P_Params loop
         for Id of Param.F_Ids loop
            if Text_Utils.Normalize_Rule_Name (Ada_Text.Node_Text (Id)) =
              Suffix_Name
            then
               return Libadalang.Analysis.Ada_Node (Id);
            end if;
         end loop;
      end loop;
      return Libadalang.Analysis.No_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Matching_Formal_Name;

   --  The defining name written by an assignment whose destination is a
   --  plain identifier, or No_Ada_Node for anything else (a more complex
   --  destination such as an array or record component) -- except for
   --  "Subp_Name.Param := ...;" inside "procedure Subp_Name (Param : out
   --  ...)", where Subp_Name is the enclosing subprogram's own name used
   --  to qualify Param (RM 8.3), typically to disambiguate it from a
   --  same-named component of an enclosing protected/task object that
   --  would otherwise shadow Param for simple-name visibility.
   --  SPARK_Readiness.Same_Parameter already recognizes this shape for
   --  the --recommended/Uninitialized_Output path (FP-011); this mirrors
   --  it for --verify's own, separate initialization tracking, which had
   --  never received the equivalent fix and so still reported a false
   --  Definite_Error on writes of this shape (FP-046).
   function Flow_Assigned_Name
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Assign_Stmt
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      declare
         Dest : constant Libadalang.Analysis.Name :=
           Node.As_Assign_Stmt.F_Dest;
      begin
         if Dest.Kind = Libadalang.Common.Ada_Identifier then
            return Flow_Referenced_Name (Dest);
         end if;

         if Dest.Kind = Libadalang.Common.Ada_Dotted_Name
           and then Dest.As_Dotted_Name.F_Suffix.Kind =
             Libadalang.Common.Ada_Identifier
         then
            declare
               Prefix_Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Dest.As_Dotted_Name.F_Prefix.P_Referenced_Decl
                   (Imprecise_Fallback => True);
               Enclosing   : constant Libadalang.Analysis.Basic_Decl :=
                 Enclosing_Subp_Body_Decl (Node);
            begin
               if not Libadalang.Analysis.Is_Null (Enclosing)
                 and then Prefix_Decl = Enclosing
               then
                  declare
                     Formal : constant Libadalang.Analysis.Ada_Node :=
                       Matching_Formal_Name
                         (Enclosing,
                          Text_Utils.Normalize_Rule_Name
                            (Ada_Text.Node_Text
                               (Dest.As_Dotted_Name.F_Suffix)));
                  begin
                     --  Not a formal: a local, named the same way below.
                     if not Libadalang.Analysis.Is_Null (Formal) then
                        return Formal;
                     end if;
                  end;
               end if;
            end;
         end if;

         --  "Pkg.Obj := ..." writes Obj.
         return Flow_Referenced_Name (Dest);
      end;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Flow_Assigned_Name;

   function Normalized_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      return Text_Utils.Normalize_Rule_Name (Ada_Text.Node_Text (Node));
   end Normalized_Text;

   function Flow_Object_Key
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Defining_Name
      then
         return "";
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Node.As_Defining_Name.P_Basic_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Decl) then
            return "";
         end if;
         return Langkit_Support.Text.To_UTF8
           (Decl.P_Unique_Identifying_Name) & ":" & Normalized_Text (Node);
      end;
   exception
      when others =>
         return "";
   end Flow_Object_Key;

   procedure Havoc_Object_Key
     (State : in out Flow_State;
      Key   : String)
   is
   begin
      if Key = "" then
         return;
      end if;
      for Index in 1 .. Binding_Count (State) loop
         declare
            Binding : constant Flow_Binding := Binding_At (State, Index);
         begin
            if Flow_Object_Key (Binding.Decl) = Key then
               Flow_Havoc (State, Binding.Decl);
            end if;
         end;
      end loop;
   end Havoc_Object_Key;

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

   type SPARK_Mode_State is record
      Has_Mode : Boolean := False;
      Is_Off   : Boolean := False;
   end record;

   function Own_SPARK_Mode
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return SPARK_Mode_State
   is
   begin
      declare
         Aspect : constant Libadalang.Analysis.Aspect :=
           Decl.P_Get_Aspect
             (Langkit_Support.Text.To_Unbounded_Text
                (Langkit_Support.Text.To_Text ("SPARK_Mode")));
      begin
         if not Libadalang.Analysis.Exists (Aspect) then
            return (Has_Mode => False, Is_Off => False);
         end if;
         return
           (Has_Mode => True,
            Is_Off   =>
              not Libadalang.Analysis.Is_Null
                (Libadalang.Analysis.Value (Aspect))
              and then Normalized_Text (Libadalang.Analysis.Value (Aspect)) =
                "off");
      end;
   exception
      when others =>
         return (Has_Mode => False, Is_Off => False);
   end Own_SPARK_Mode;

   --  The SPARK_Mode that applies to the whole compilation unit holding
   --  Node when no declaration in it says otherwise: a "pragma SPARK_Mode"
   --  written before the unit, or else the configuration pragmas of the
   --  project the source belongs to.
   function Unit_SPARK_Mode
     (Node : Libadalang.Analysis.Ada_Node'Class) return SPARK_Mode_State
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Node);
   begin
      while not Libadalang.Analysis.Is_Null (Current)
        and then Current.Kind /= Libadalang.Common.Ada_Compilation_Unit
      loop
         Current := Current.Parent;
      end loop;

      if not Libadalang.Analysis.Is_Null (Current) then
         for Item of Current.As_Compilation_Unit.F_Prelude loop
            if Item.Kind = Libadalang.Common.Ada_Pragma_Node
              and then Normalized_Text (Item.As_Pragma_Node.F_Id) =
                "spark-mode"
            then
               return
                 (Has_Mode => True,
                  Is_Off   =>
                    Item.As_Pragma_Node.F_Args.Children_Count > 0
                    and then Normalized_Text
                      (Item.As_Pragma_Node.F_Args.Child (1)) = "off");
            end if;
         end loop;
      end if;

      return
        (Has_Mode => Adalang_Analyzer.Project_Files.Under_Project_SPARK_Mode
           (Node.Unit.Get_Filename),
         Is_Off   => False);
   exception
      when others =>
         return (Has_Mode => False, Is_Off => False);
   end Unit_SPARK_Mode;

   --  True when Decl's library unit is declared Pure, so nothing in
   --  it has state to change.
   function In_Pure_Unit
     (Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
      Top : constant Libadalang.Analysis.Basic_Decl :=
        Decl.P_Top_Level_Decl (Decl.Unit);
   begin
      return not Libadalang.Analysis.Is_Null (Top)
        and then Top.P_Has_Aspect
          (Langkit_Support.Text.To_Unbounded_Text
             (Langkit_Support.Text.To_Text ("Pure")));
   exception
      when others =>
         return False;
   end In_Pure_Unit;

   --  True when Decl is under an explicit SPARK_Mode (On): a SPARK
   --  function has no side effects unless it says so.
   function Explicitly_SPARK
     (Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
      Mode     : SPARK_Mode_State := Own_SPARK_Mode (Decl);
      Ancestor : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Decl).Parent;
   begin
      while not Mode.Has_Mode
        and then not Libadalang.Analysis.Is_Null (Ancestor)
      loop
         if Ancestor.Kind in Libadalang.Common.Ada_Package_Body
                           | Libadalang.Common.Ada_Package_Decl
                           | Libadalang.Common.Ada_Generic_Package_Decl
                           | Libadalang.Common.Ada_Subp_Body
         then
            Mode := Own_SPARK_Mode (Ancestor.As_Basic_Decl);
         end if;
         Ancestor := Ancestor.Parent;
      end loop;
      if not Mode.Has_Mode then
         Mode := Unit_SPARK_Mode (Decl);
      end if;
      return Mode.Has_Mode and then not Mode.Is_Off
        and then not Has_Aspect (Decl, "Side_Effects");
   exception
      when others =>
         return False;
   end Explicitly_SPARK;

   --  True when Decl is a function that the language or its own unit says
   --  has no side effects: one declared in a Pure unit, or under an
   --  explicit SPARK_Mode without the Side_Effects aspect.
   function Function_Declared_Pure
     (Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Decl)
        or else Libadalang.Analysis.Is_Null (Decl.P_Subp_Spec_Or_Null)
        or else Decl.P_Subp_Spec_Or_Null.As_Subp_Spec.F_Subp_Kind.Kind /=
          Libadalang.Common.Ada_Subp_Kind_Function
      then
         return False;
      end if;
      return In_Pure_Unit (Decl) or else Explicitly_SPARK (Decl);
   exception
      when others =>
         return False;
   end Function_Declared_Pure;

   --  True when Call is to a literal, a predefined operation or a
   --  function under an explicit SPARK_Mode: what is taken to leave
   --  every object as it is, those reached through access values too.
   function Leaves_Everything_Alone
     (Call : Libadalang.Analysis.Name'Class) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      return not Libadalang.Analysis.Is_Null (Decl)
        and then
          (Decl.Kind in Libadalang.Common.Ada_Enum_Literal_Decl
                      | Libadalang.Common.Ada_Synthetic_Char_Enum_Lit
                      | Libadalang.Common.Ada_Synthetic_Subp_Decl
           or else Explicitly_SPARK (Decl));
   exception
      when others =>
         return False;
   end Leaves_Everything_Alone;

   function Effective_SPARK_Enabled
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Mode     : SPARK_Mode_State;
      Ancestor : Libadalang.Analysis.Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return True;
      end if;

      Mode := Own_SPARK_Mode (Decl);
      if Mode.Has_Mode then
         return not Mode.Is_Off;
      end if;

      --  SPARK_Mode was not set directly on Decl: per the SPARK RM it is
      --  inherited from the nearest enclosing package/subprogram/task/
      --  protected body or spec. Libadalang's own aspect lookup only
      --  follows type derivation for inheritance, not lexical scoping,
      --  so the enclosing bodies/specs are walked by hand here.
      Ancestor := Libadalang.Analysis.Ada_Node (Decl).Parent;
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         case Ancestor.Kind is
            when Libadalang.Common.Ada_Package_Body
               | Libadalang.Common.Ada_Package_Decl
               | Libadalang.Common.Ada_Generic_Package_Decl
               | Libadalang.Common.Ada_Subp_Body
               | Libadalang.Common.Ada_Task_Body
               | Libadalang.Common.Ada_Protected_Body
            =>
               Mode := Own_SPARK_Mode (Ancestor.As_Basic_Decl);
               if Mode.Has_Mode then
                  return not Mode.Is_Off;
               end if;
            when others =>
               null;
         end case;
         Ancestor := Ancestor.Parent;
      end loop;

      Mode := Unit_SPARK_Mode (Decl);
      return not (Mode.Has_Mode and then Mode.Is_Off);
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

   --  The subtype a formal parameter is declared with; null when it is
   --  not found.
   function Formal_Subtype
     (Param : Libadalang.Analysis.Defining_Name'Class)
      return Libadalang.Analysis.Base_Type_Decl
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Param);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return Current.As_Param_Spec.F_Type_Expr.P_Designated_Type_Decl;
         end if;
         Current := Current.Parent;
      end loop;

      return Libadalang.Analysis.No_Base_Type_Decl;
   exception
      when others =>
         return Libadalang.Analysis.No_Base_Type_Decl;
   end Formal_Subtype;

   --  As Formal_Subtype, the subtype of the formal as it is written.
   function Formal_Type_Expr
     (Param : Libadalang.Analysis.Defining_Name'Class)
      return Libadalang.Analysis.Type_Expr
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Param);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return Current.As_Param_Spec.F_Type_Expr;
         end if;
         Current := Current.Parent;
      end loop;
      return Libadalang.Analysis.No_Type_Expr;
   exception
      when others =>
         return Libadalang.Analysis.No_Type_Expr;
   end Formal_Type_Expr;

   --  True when the subtype Typ has every value of its type: a modular
   --  type, a predefined integer type, or a subtype or a derived type that
   --  adds no constraint to one. A value of the type needs no range check
   --  to be stored under such a subtype.
   function Covers_Its_Type
     (Typ : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return False;
         elsif Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            if not Libadalang.Analysis.Is_Null
                     (Current.As_Subtype_Decl.F_Subtype.F_Constraint)
            then
               return False;
            end if;
            Current :=
              Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
         elsif Current.Kind not in Libadalang.Common.Ada_Type_Decl then
            return False;
         else
            declare
               Definition : constant Libadalang.Analysis.Type_Def :=
                 Current.As_Type_Decl.F_Type_Def;
            begin
               if Libadalang.Analysis.Is_Null (Definition) then
                  return False;
               end if;

               case Definition.Kind is
                  when Libadalang.Common.Ada_Mod_Int_Type_Def =>
                     return True;
                  when Libadalang.Common.Ada_Signed_Int_Type_Def =>
                     --  Only a predefined type is declared with the whole
                     --  range of its base type.
                     declare
                        Name : constant String :=
                          Langkit_Support.Text.To_UTF8
                            (Current.P_Canonical_Fully_Qualified_Name);
                     begin
                        return Name'Length > 9
                          and then Name (Name'First .. Name'First + 8) =
                            "standard.";
                     end;
                  when Libadalang.Common.Ada_Derived_Type_Def =>
                     if not Libadalang.Analysis.Is_Null
                              (Definition.As_Derived_Type_Def
                                 .F_Subtype_Indication.F_Constraint)
                     then
                        return False;
                     end if;
                     Current :=
                       Definition.As_Derived_Type_Def.F_Subtype_Indication
                         .P_Designated_Type_Decl;
                  when others =>
                     return False;
               end case;
            end;
         end if;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Covers_Its_Type;

   --  What the declarations Typ is built from say about its values: the
   --  tightest range among Typ and the subtypes and types it is declared
   --  from, each of which contains the next.
   type Subtype_Facts is record
      Bounds : Abstract_Range := Unknown_Range;
   end record;

   function Subtype_Chain_Facts
     (Typ : Libadalang.Analysis.Base_Type_Decl) return Subtype_Facts
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
      Result    : Subtype_Facts;

      procedure Tighten (Bounds : Abstract_Range) is
      begin
         if Bounds.Has_Low
           and then (not Result.Bounds.Has_Low
                     or else Bounds.Low > Result.Bounds.Low)
         then
            Result.Bounds.Has_Low := True;
            Result.Bounds.Low := Bounds.Low;
         end if;
         if Bounds.Has_High
           and then (not Result.Bounds.Has_High
                     or else Bounds.High < Result.Bounds.High)
         then
            Result.Bounds.Has_High := True;
            Result.Bounds.High := Bounds.High;
         end if;
      end Tighten;
   begin
      for Depth in 1 .. Max_Depth loop
         exit when Libadalang.Analysis.Is_Null (Current)
           or else not Current.P_Is_Int_Type;

         declare
            Bounds : constant Abstract_Range :=
              Type_Range (Current, Empty_Flow_State);
         begin
            Tighten (Bounds);

            if Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
               Current :=
                 Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
            elsif Current.Kind not in Libadalang.Common.Ada_Type_Decl
              or else Libadalang.Analysis.Is_Null
                        (Current.As_Type_Decl.F_Type_Def)
            then
               exit;
            elsif Current.As_Type_Decl.F_Type_Def.Kind =
              Libadalang.Common.Ada_Derived_Type_Def
            then
               Current :=
                 Current.As_Type_Decl.F_Type_Def.As_Derived_Type_Def
                   .F_Subtype_Indication.P_Designated_Type_Decl;
            else
               exit;
            end if;
         end;
      end loop;
      return Result;
   exception
      when others =>
         return (others => <>);
   end Subtype_Chain_Facts;

   --  True when Typ is Ancestor or a subtype declared, directly or through
   --  other subtypes, from it: each value of Typ is then one of Ancestor.
   function Is_Subtype_Of
     (Typ      : Libadalang.Analysis.Base_Type_Decl;
      Ancestor : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return False;
         elsif Libadalang.Analysis.Ada_Node (Current) =
           Libadalang.Analysis.Ada_Node (Ancestor)
         then
            return True;
         elsif Current.Kind /= Libadalang.Common.Ada_Subtype_Decl then
            return False;
         end if;
         Current := Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Is_Subtype_Of;

   --  The range a compiler can tell Value is in from its form alone, with
   --  no knowledge of the state: its value when it is static; the range of
   --  its subtype when it is a name, a call, a conversion or a qualified
   --  expression; for an arithmetic operation, the interval its operands'
   --  ranges give. A range check into a subtype that contains this range is
   --  one a compiler removes, and GNATprove does not have.
   function Static_Subtype_Range
     (Value : Libadalang.Analysis.Ada_Node'Class) return Abstract_Range
   is
      function Point (Item : Long_Long_Integer) return Abstract_Range
      is (Has_Low => True, Low => Item, Has_High => True, High => Item);

      function Known (Item : Abstract_Range) return Boolean
      is (Item.Has_Low and then Item.Has_High);

      procedure Set_Low
        (Item : in out Abstract_Range; Bound : Abstract_Int) is
      begin
         Item.Has_Low := Bound.Known;
         Item.Low := Bound.Value;
      end Set_Low;

      procedure Set_High
        (Item : in out Abstract_Range; Bound : Abstract_Int) is
      begin
         Item.Has_High := Bound.Known;
         Item.High := Bound.Value;
      end Set_High;

      --  The value of Value when it is a static expression that
      --  Integer_Value does not fold, such as one with a static attribute.
      function Static_Value return Abstract_Int is
      begin
         if Value.As_Expr.P_Is_Static_Expr then
            return Known_Int
              (Long_Long_Integer'Value
                 (GNATCOLL.GMP.Integers.Image
                    (Value.As_Expr.P_Eval_As_Int)));
         end if;
         return Unknown_Int;
      exception
         when others =>
            return Unknown_Int;
      end Static_Value;

      --  An interval is of use only with both of its ends: an operation
      --  whose result may leave it on one side is one a compiler keeps
      --  the check for.
      function Within_Base (Item : Abstract_Range) return Abstract_Range
      is (if Known (Item) then Item else Unknown_Range);
   begin
      if Libadalang.Analysis.Is_Null (Value)
        or else Value.Kind not in Libadalang.Common.Ada_Expr
      then
         return Unknown_Range;
      elsif Value.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Static_Subtype_Range (Value.As_Paren_Expr.F_Expr);
      elsif Is_User_Operator (Value) then
         --  A call: what it returns is in the subtype of its result.
         return
           Subtype_Chain_Facts (Value.As_Expr.P_Expression_Type).Bounds;
      end if;

      declare
         Folded : constant Abstract_Int :=
           Integer_Value (Value, Empty_Flow_State);
      begin
         if Folded.Known then
            return Point (Folded.Value);
         end if;
      end;

      declare
         Static : constant Abstract_Int := Static_Value;
      begin
         if Static.Known then
            return Point (Static.Value);
         end if;
      end;

      case Value.Kind is
         when Libadalang.Common.Ada_Identifier
            | Libadalang.Common.Ada_Dotted_Name
            | Libadalang.Common.Ada_Call_Expr
            | Libadalang.Common.Ada_Qual_Expr
            | Libadalang.Common.Ada_Explicit_Deref =>
            declare
               Result : Abstract_Range :=
                 Subtype_Chain_Facts
                   (Value.As_Expr.P_Expression_Type).Bounds;
            begin
               --  A conversion between integer types keeps the value, so
               --  what is known of the operand holds for the result too.
               if Value.Kind = Libadalang.Common.Ada_Call_Expr
                 and then Value.As_Call_Expr.P_Kind in
                   Libadalang.Common.Type_Conversion
               then
                  declare
                     Suffix  : constant Libadalang.Analysis.Ada_Node :=
                       Value.As_Call_Expr.F_Suffix;
                     Operand : constant Libadalang.Analysis.Expr :=
                       (if Suffix.Kind in Libadalang.Common.Ada_Expr
                        then Suffix.As_Expr
                        elsif Suffix.Children_Count = 1
                          and then Suffix.Child (1).Kind =
                            Libadalang.Common.Ada_Param_Assoc
                        then Suffix.Child (1).As_Param_Assoc.F_R_Expr
                        else Libadalang.Analysis.No_Expr);
                     Inner   : Abstract_Range := Unknown_Range;
                  begin
                     if not Libadalang.Analysis.Is_Null (Operand)
                       and then not Libadalang.Analysis.Is_Null
                                      (Operand.P_Expression_Type)
                       and then Operand.P_Expression_Type.P_Is_Int_Type
                     then
                        Inner := Static_Subtype_Range (Operand);
                     end if;
                     if Inner.Has_Low
                       and then (not Result.Has_Low
                                 or else Inner.Low > Result.Low)
                     then
                        Result.Has_Low := True;
                        Result.Low := Inner.Low;
                     end if;
                     if Inner.Has_High
                       and then (not Result.Has_High
                                 or else Inner.High < Result.High)
                     then
                        Result.Has_High := True;
                        Result.High := Inner.High;
                     end if;
                  end;
               end if;
               return Result;
            end;

         when Libadalang.Common.Ada_Attribute_Ref =>
            declare
               Attr   : constant Libadalang.Analysis.Attribute_Ref :=
                 Value.As_Attribute_Ref;
               Name   : constant String :=
                 Text_Utils.Normalize_Rule_Name
                   (Ada_Text.Node_Text (Attr.F_Attribute));
               Prefix : constant Libadalang.Analysis.Basic_Decl :=
                 Attr.F_Prefix.P_Referenced_Decl;
               --  The type the prefix names, or that of the object it
               --  names.
               Typ    : constant Libadalang.Analysis.Base_Type_Decl :=
                 (if not Libadalang.Analysis.Is_Null (Prefix)
                    and then Prefix.Kind in
                      Libadalang.Common.Ada_Base_Type_Decl
                  then Prefix.As_Base_Type_Decl
                  else Attr.F_Prefix.P_Expression_Type);
            begin
               if Libadalang.Analysis.Is_Null (Typ)
                 or else
                   (not Libadalang.Analysis.Is_Null (Attr.F_Args)
                    and then Attr.F_Args.Children_Count > 0)
               then
                  return Unknown_Range;
               elsif Name = "size" and then Typ.P_Is_Scalar_Type then
                  --  No scalar is larger than 128 bits.
                  return
                    (Has_Low => True, Low => 0,
                     Has_High => True, High => 128);
               end if;
               return Unknown_Range;
            end;

         when Libadalang.Common.Ada_If_Expr =>
            --  One of the dependent expressions, whichever it is.
            declare
               Expr   : constant Libadalang.Analysis.If_Expr :=
                 Value.As_If_Expr;
               Result : Abstract_Range :=
                 Static_Subtype_Range (Expr.F_Then_Expr);

               procedure Include (Item : Abstract_Range) is
               begin
                  Result.Has_Low := Result.Has_Low and then Item.Has_Low;
                  Result.Has_High := Result.Has_High and then Item.Has_High;
                  if Result.Has_Low then
                     Result.Low :=
                       Long_Long_Integer'Min (Result.Low, Item.Low);
                  end if;
                  if Result.Has_High then
                     Result.High :=
                       Long_Long_Integer'Max (Result.High, Item.High);
                  end if;
               end Include;
            begin
               if Libadalang.Analysis.Is_Null (Expr.F_Else_Expr) then
                  return Unknown_Range;
               end if;
               for Part of Expr.F_Alternatives loop
                  Include
                    (Static_Subtype_Range
                       (Part.As_Elsif_Expr_Part.F_Then_Expr));
               end loop;
               Include (Static_Subtype_Range (Expr.F_Else_Expr));
               return Result;
            end;

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Operand : constant Abstract_Range :=
                 Static_Subtype_Range (Value.As_Un_Op.F_Expr);
               Result  : Abstract_Range := Unknown_Range;
            begin
               if not Known (Operand) then
                  return Unknown_Range;
               end if;

               case Value.As_Un_Op.F_Op.Kind is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Operand;
                  when Libadalang.Common.Ada_Op_Minus =>
                     Set_Low (Result, Safe_Sub (0, Operand.High));
                     Set_High (Result, Safe_Sub (0, Operand.Low));
                  when Libadalang.Common.Ada_Op_Abs =>
                     if Operand.Low >= 0 then
                        return Operand;
                     end if;
                     Set_Low (Result, Known_Int (0));
                     Set_High
                       (Result,
                        (if Operand.High >= 0
                           and then Safe_Sub (0, Operand.Low).Known
                         then Known_Int
                                (Long_Long_Integer'Max
                                   (Operand.High, -Operand.Low))
                         else Safe_Sub (0, Operand.Low)));
                  when others =>
                     return Unknown_Range;
               end case;
               return Within_Base (Result);
            end;

         when Libadalang.Common.Ada_Bin_Op =>
            declare
               Left   : constant Abstract_Range :=
                 Static_Subtype_Range (Value.As_Bin_Op.F_Left);
               Right  : constant Abstract_Range :=
                 Static_Subtype_Range (Value.As_Bin_Op.F_Right);
               Result : Abstract_Range := Unknown_Range;
            begin
               case Value.As_Bin_Op.F_Op.Kind is
                  when Libadalang.Common.Ada_Op_Plus =>
                     if not Known (Left) or else not Known (Right) then
                        return Unknown_Range;
                     end if;
                     Set_Low (Result, Safe_Add (Left.Low, Right.Low));
                     Set_High (Result, Safe_Add (Left.High, Right.High));

                  when Libadalang.Common.Ada_Op_Minus =>
                     if not Known (Left) or else not Known (Right) then
                        return Unknown_Range;
                     end if;
                     Set_Low (Result, Safe_Sub (Left.Low, Right.High));
                     Set_High (Result, Safe_Sub (Left.High, Right.Low));

                  when Libadalang.Common.Ada_Op_Mult =>
                     --  Of two ranges without a negative value: the sign
                     --  cases are not needed where a check is removed.
                     if not Known (Left) or else not Known (Right)
                       or else Left.Low < 0 or else Right.Low < 0
                     then
                        return Unknown_Range;
                     end if;
                     Set_Low (Result, Safe_Mul (Left.Low, Right.Low));
                     Set_High (Result, Safe_Mul (Left.High, Right.High));

                  when Libadalang.Common.Ada_Op_Div =>
                     if not Known (Left) or else not Known (Right)
                       or else Left.Low < 0 or else Right.Low < 1
                     then
                        return Unknown_Range;
                     end if;
                     Set_Low (Result, Known_Int (Left.Low / Right.High));
                     Set_High (Result, Known_Int (Left.High / Right.Low));

                  when Libadalang.Common.Ada_Op_Mod =>
                     if not Known (Right) or else Right.Low < 1 then
                        return Unknown_Range;
                     end if;
                     return
                       (Has_Low => True, Low => 0,
                        Has_High => True, High => Right.High - 1);

                  when Libadalang.Common.Ada_Op_Rem =>
                     if not Known (Left) or else not Known (Right)
                       or else Left.Low < 0 or else Right.Low < 1
                     then
                        return Unknown_Range;
                     end if;
                     return
                       (Has_Low => True, Low => 0,
                        Has_High => True, High => Right.High - 1);

                  when others =>
                     return Unknown_Range;
               end case;
               return Within_Base (Result);
            end;

         when others =>
            return Unknown_Range;
      end case;
   exception
      when others =>
         return Unknown_Range;
   end Static_Subtype_Range;

   function Formal_Is_Writable
     (Param : Libadalang.Analysis.Defining_Name'Class) return Boolean is
   begin
      return Formal_Mode (Param) in Libadalang.Common.Ada_Mode_Out
        | Libadalang.Common.Ada_Mode_In_Out;
   end Formal_Is_Writable;

   --  The oracle of VC.Set_Function_Oracle. A function of its arguments
   --  is a function under an explicit SPARK_Mode, so with no side effect,
   --  that is not volatile, writes no parameter and is known to touch no
   --  object declared outside it: its result is then settled by the
   --  values it is given. The answer for a call does not change, and is
   --  kept.
   package Call_Answer_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Libadalang.Analysis.Ada_Node,
      Element_Type    => Boolean,
      Hash            => Libadalang.Analysis.Hash,
      Equivalent_Keys => Libadalang.Analysis."=");
   Functions_Of_Arguments : Call_Answer_Maps.Map;

   procedure Decide_Function_Of_Arguments
     (Call   : Libadalang.Analysis.Name'Class;
      Answer : out Boolean)
   is
      Key      : constant Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Call);
      Position : constant Call_Answer_Maps.Cursor :=
        Functions_Of_Arguments.Find (Key);

      function Decided return Boolean is
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Call_Declaration (Call);
         Part : Libadalang.Analysis.Basic_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Decl)
           or else Libadalang.Analysis.Is_Null (Decl.P_Subp_Spec_Or_Null)
           or else Decl.P_Subp_Spec_Or_Null.As_Subp_Spec.F_Subp_Kind.Kind /=
             Libadalang.Common.Ada_Subp_Kind_Function
           or else not Explicitly_SPARK (Decl)
           or else Has_Aspect (Decl, "Volatile_Function")
         then
            return False;
         end if;

         --  The aspects may be on the declaration the body completes.
         Part := Contract_Part (Decl);
         if not Libadalang.Analysis.Is_Null (Part)
           and then (Has_Aspect (Part, "Volatile_Function")
                     or else Has_Aspect (Part, "Side_Effects"))
         then
            return False;
         end if;

         for Pair of Call.P_Call_Params loop
            if Formal_Is_Writable (Libadalang.Analysis.Param (Pair)) then
               return False;
            end if;
         end loop;
         return Adalang_Analyzer.Flow_Contracts.Touches_Nothing_Outside
           (Decl, Call);
      exception
         when others =>
            return False;
      end Decided;
   begin
      if Call_Answer_Maps.Has_Element (Position) then
         Answer := Call_Answer_Maps.Element (Position);
         return;
      end if;
      Answer := Decided;
      Functions_Of_Arguments.Include (Key, Answer);
   end Decide_Function_Of_Arguments;

   function Is_Function_Of_Arguments
     (Call : Libadalang.Analysis.Name'Class) return Boolean
   is
      Answer : Boolean;
   begin
      Decide_Function_Of_Arguments (Call, Answer);
      return Answer;
   end Is_Function_Of_Arguments;

   --  What Symbols still says once the procedure call Stmt has returned,
   --  After being the flow state then. Where the callee's effects on
   --  objects by name are known -- from its summary or its Global aspect --
   --  and it is not declared inside the subprogram being verified, whose
   --  own objects it could then reach, the scalars of that subprogram
   --  which the call does not name keep what is known of them. Otherwise
   --  nothing is kept.
   function Symbols_After_Call
     (Symbols : VC.Symbolic_State;
      Stmt    : Libadalang.Analysis.Call_Stmt;
      After   : Flow_State) return VC.Symbolic_State
   is
      Call   : constant Libadalang.Analysis.Name := Stmt.F_Call;
      Decl   : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
      Result : VC.Symbolic_State;

      procedure Forget_Identifiers_In
        (Node : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Identifier then
            Result :=
              VC.Forget_Object
                (Result, Stmt, Flow_Referenced_Name (Node), After);
         end if;
         for Index in 1 .. Node.Children_Count loop
            Forget_Identifiers_In (Node.Child (Index));
         end loop;
      end Forget_Identifiers_In;
   begin
      if Libadalang.Analysis.Is_Null (Decl)
        or else Libadalang.Analysis.Is_Null (Verified_Subprogram)
        or else Inside_Verified_Subprogram (Decl)
        or else Call.P_Is_Dispatching_Call
        or else not
          (Adalang_Analyzer.Subprogram_Summaries.Callee_State_Effects_Known
             (Call)
           or else not Libadalang.Analysis.Is_Null
                         (Contract_Expression (Decl, "Global")))
      then
         return VC.Havoc;
      end if;

      Result :=
        VC.Forget_Unowned_Values (Symbols, Stmt, Verified_Subprogram, After);
      for Pair of Call.P_Call_Params loop
         if Formal_Is_Writable (Libadalang.Analysis.Param (Pair)) then
            Forget_Identifiers_In (Libadalang.Analysis.Actual (Pair));
         end if;
      end loop;
      return Result;
   exception
      when others =>
         return VC.Havoc;
   end Symbols_After_Call;

   --  True unless every function Node calls is known to leave state as it
   --  is: a literal, a predefined operation, a function whose summary shows
   --  no write, or one its unit or SPARK_Mode declares free of side
   --  effects. For an expression of another subprogram, a callee's
   --  contract, where Effectful_Call_Reach says nothing.
   function Calls_May_Change_State
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      function May_Change (Call : Libadalang.Analysis.Name) return Boolean is
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Call_Declaration (Call);
      begin
         if Libadalang.Analysis.Is_Null (Decl) then
            return True;
         elsif Decl.Kind in Libadalang.Common.Ada_Enum_Literal_Decl
                          | Libadalang.Common.Ada_Synthetic_Char_Enum_Lit
                          | Libadalang.Common.Ada_Synthetic_Subp_Decl
         then
            return False;
         end if;
         for Pair of Call.P_Call_Params loop
            if Formal_Is_Writable (Libadalang.Analysis.Param (Pair)) then
               return True;
            end if;
         end loop;
         if Adalang_Analyzer.Subprogram_Summaries
              .Callee_State_Effects_Known (Call)
         then
            return Adalang_Analyzer.Subprogram_Summaries
              .Callee_Global_Write_Count (Call) > 0;
         end if;
         return not Function_Declared_Pure (Decl);
      exception
         when others =>
            return True;
      end May_Change;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Call_Expr =>
            if Node.As_Call_Expr.P_Kind = Libadalang.Common.Call
              and then May_Change (Node.As_Call_Expr.F_Name)
            then
               return True;
            end if;
         when Libadalang.Common.Ada_Identifier
            | Libadalang.Common.Ada_Dotted_Name =>
            if Node.Parent.Kind /= Libadalang.Common.Ada_Call_Expr
              and then Node.As_Name.P_Is_Call
              and then May_Change (Node.As_Name)
            then
               return True;
            end if;
         when Libadalang.Common.Ada_Bin_Op_Range =>
            if not Libadalang.Analysis.Is_Null
                     (Node.As_Bin_Op.F_Op.P_Referenced_Decl)
              and then May_Change (Node.As_Bin_Op.F_Op.As_Name)
            then
               return True;
            end if;
         when Libadalang.Common.Ada_Un_Op =>
            if not Libadalang.Analysis.Is_Null
                     (Node.As_Un_Op.F_Op.P_Referenced_Decl)
              and then May_Change (Node.As_Un_Op.F_Op.As_Name)
            then
               return True;
            end if;
         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for Index in 1 .. Node.Children_Count loop
         if Calls_May_Change_State (Node.Child (Index)) then
            return True;
         end if;
      end loop;
      return False;
   exception
      when others =>
         return True;
   end Calls_May_Change_State;

   --  True when Left and Right name an object in common: any identifier
   --  of one that denotes what an identifier of the other does.
   function Shares_Object
     (Left, Right : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      function Names
        (Node : Libadalang.Analysis.Ada_Node'Class;
         Key  : Libadalang.Analysis.Ada_Node) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif Node.Kind = Libadalang.Common.Ada_Identifier
           and then Flow_Referenced_Name (Node) = Key
         then
            return True;
         end if;
         for Index in 1 .. Node.Children_Count loop
            if Names (Node.Child (Index), Key) then
               return True;
            end if;
         end loop;
         return False;
      end Names;

      function Any_Shared
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif Node.Kind = Libadalang.Common.Ada_Identifier then
            declare
               Key : constant Libadalang.Analysis.Ada_Node :=
                 Flow_Referenced_Name (Node);
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 (if Libadalang.Analysis.Is_Null (Key)
                  then Libadalang.Analysis.No_Basic_Decl
                  else Key.As_Defining_Name.P_Basic_Decl);
            begin
               if not Libadalang.Analysis.Is_Null (Decl)
                 and then Decl.Kind in
                   Libadalang.Common.Ada_Object_Decl_Range
                     | Libadalang.Common.Ada_Param_Spec
                 and then Names (Right, Key)
               then
                  return True;
               end if;
            end;
         end if;
         for Index in 1 .. Node.Children_Count loop
            if Any_Shared (Node.Child (Index)) then
               return True;
            end if;
         end loop;
         return False;
      end Any_Shared;
   begin
      return Any_Shared (Left);
   exception
      when others =>
         return True;
   end Shares_Object;

   --  True unless every function Node calls is taken to leave everything
   --  as it is, what is reached through access values included: a
   --  literal, a predefined operation, a function under an explicit
   --  SPARK_Mode.
   function Calls_Something_Untrusted
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Call_Expr =>
            if Node.As_Call_Expr.P_Kind = Libadalang.Common.Call
              and then not Leaves_Everything_Alone (Node.As_Call_Expr.F_Name)
            then
               return True;
            end if;
         when Libadalang.Common.Ada_Identifier
            | Libadalang.Common.Ada_Dotted_Name =>
            if Node.Parent.Kind /= Libadalang.Common.Ada_Call_Expr
              and then Node.As_Name.P_Is_Call
              and then not Leaves_Everything_Alone (Node.As_Name)
            then
               return True;
            end if;
         when Libadalang.Common.Ada_Bin_Op_Range =>
            if not Libadalang.Analysis.Is_Null
                     (Node.As_Bin_Op.F_Op.P_Referenced_Decl)
              and then not Leaves_Everything_Alone
                             (Node.As_Bin_Op.F_Op.As_Name)
            then
               return True;
            end if;
         when Libadalang.Common.Ada_Un_Op =>
            if not Libadalang.Analysis.Is_Null
                     (Node.As_Un_Op.F_Op.P_Referenced_Decl)
              and then not Leaves_Everything_Alone
                             (Node.As_Un_Op.F_Op.As_Name)
            then
               return True;
            end if;
         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for Index in 1 .. Node.Children_Count loop
         if Calls_Something_Untrusted (Node.Child (Index)) then
            return True;
         end if;
      end loop;
      return False;
   exception
      when others =>
         return True;
   end Calls_Something_Untrusted;

   --  Symbols, the symbolic state once the procedure call Stmt has
   --  returned, with what the callee's postcondition says, After being the
   --  flow state then. The postcondition is assumed as an assertion is:
   --  whether it holds is the obligation of the callee's own verification.
   --
   --  It speaks of the callee's formals, and each one is given what it
   --  stands for after the call:
   --
   --  - a formal the call writes, the object that is its actual, when
   --    that is an object of the subprogram being verified;
   --  - any other formal, its actual as it is after the call, when the
   --    call cannot have changed what the actual reads: literals,
   --    constants, and objects of the subprogram being verified that the
   --    call does not write.
   --
   --  A formal with neither is blocked, and what the postcondition says
   --  with it is not assumed. Nothing is assumed at all where a fact could
   --  be about another value than the caller sees: a callee declared
   --  inside the subprogram being verified, which can name its objects; an
   --  actual the call writes that is declared outside it, which the
   --  callee can name too; one object passed twice; an access or address
   --  taken in an actual; a dispatching call; a postcondition that calls
   --  a function which may change something.
   function With_Call_Postcondition
     (Symbols : VC.Symbolic_State;
      Stmt    : Libadalang.Analysis.Call_Stmt;
      After   : Flow_State) return VC.Symbolic_State
   is
      Call   : constant Libadalang.Analysis.Name := Stmt.F_Call;
      Decl   : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
      Part   : Libadalang.Analysis.Basic_Decl :=
        Libadalang.Analysis.No_Basic_Decl;
      Post   : Libadalang.Analysis.Expr;
      Frame  : VC.Contract_Frame := VC.Empty_Contract_Frame;
      Result : VC.Symbolic_State := Symbols;
      Written : Call_Sets.Set;

      --  The objects named in what the call writes. False when one of
      --  them is declared outside the subprogram being verified.
      function Note_Written
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return True;
         elsif Node.Kind = Libadalang.Common.Ada_Identifier then
            declare
               Key : constant Libadalang.Analysis.Ada_Node :=
                 Flow_Referenced_Name (Node);
            begin
               if not Libadalang.Analysis.Is_Null (Key) then
                  if not Inside_Verified_Subprogram (Key) then
                     return False;
                  end if;
                  Written.Include (Key);
               end if;
            end;
         end if;
         for Index in 1 .. Node.Children_Count loop
            if not Note_Written (Node.Child (Index)) then
               return False;
            end if;
         end loop;
         return True;
      end Note_Written;

      function Takes_Access
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif Node.Kind = Libadalang.Common.Ada_Attribute_Ref
           and then Normalized_Text (Node.As_Attribute_Ref.F_Attribute) in
             "access" | "unchecked-access" | "unrestricted-access"
               | "address"
         then
            return True;
         end if;
         for Index in 1 .. Node.Children_Count loop
            if Takes_Access (Node.Child (Index)) then
               return True;
            end if;
         end loop;
         return False;
      end Takes_Access;

      --  True when Node has, after the call, the value it had when the
      --  call was made: it reads nothing the call can have changed.
      function Unchanged
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif not Libadalang.Analysis.Is_Null (Expanded_Name_Target (Node))
         then
            return Unchanged (Expanded_Name_Target (Node));
         end if;

         case Node.Kind is
            when Libadalang.Common.Ada_Int_Literal
               | Libadalang.Common.Ada_Char_Literal =>
               return True;
            when Libadalang.Common.Ada_Paren_Expr =>
               return Unchanged (Node.As_Paren_Expr.F_Expr);
            when Libadalang.Common.Ada_Qual_Expr =>
               return Unchanged (Node.As_Qual_Expr.F_Suffix);
            when Libadalang.Common.Ada_Un_Op =>
               return Libadalang.Analysis.Is_Null
                        (Node.As_Un_Op.F_Op.P_Referenced_Decl)
                 and then Unchanged (Node.As_Un_Op.F_Expr);
            when Libadalang.Common.Ada_Bin_Op_Range =>
               return Libadalang.Analysis.Is_Null
                        (Node.As_Bin_Op.F_Op.P_Referenced_Decl)
                 and then Unchanged (Node.As_Bin_Op.F_Left)
                 and then Unchanged (Node.As_Bin_Op.F_Right);
            when Libadalang.Common.Ada_Identifier =>
               declare
                  Target : constant Libadalang.Analysis.Basic_Decl :=
                    Node.As_Name.P_Referenced_Decl;
                  Key    : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Referenced_Name (Node);
               begin
                  if Libadalang.Analysis.Is_Null (Target) then
                     return False;
                  end if;
                  case Target.Kind is
                     when Libadalang.Common.Ada_Enum_Literal_Decl
                        | Libadalang.Common.Ada_Synthetic_Char_Enum_Lit
                        | Libadalang.Common.Ada_Number_Decl
                        | Libadalang.Common.Ada_For_Loop_Var_Decl =>
                        return True;
                     when Libadalang.Common.Ada_Object_Decl_Range =>
                        if not Libadalang.Analysis.Is_Null
                                 (Target.As_Object_Decl.F_Renaming_Clause)
                        then
                           return False;
                        end if;
                        return Target.As_Object_Decl.F_Has_Constant
                          or else
                            (Inside_Verified_Subprogram (Key)
                             and then not Written.Contains (Key));
                     when Libadalang.Common.Ada_Param_Spec =>
                        return Inside_Verified_Subprogram (Key)
                          and then not Written.Contains (Key);
                     when others =>
                        return False;
                  end case;
               end;
            when others =>
               return False;
         end case;
      exception
         when others =>
            return False;
      end Unchanged;

      procedure Block_All (Subprogram : Libadalang.Analysis.Basic_Decl) is
      begin
         if Libadalang.Analysis.Is_Null (Subprogram) then
            return;
         end if;
         for Param of Subprogram.P_Subp_Spec_Or_Null.P_Params loop
            for Id of Param.F_Ids loop
               VC.Block_Formal (Frame, Libadalang.Analysis.Ada_Node (Id));
            end loop;
         end loop;
      end Block_All;
   begin
      if not Config.Verification_Mode
        or else Libadalang.Analysis.Is_Null (Decl)
        or else Libadalang.Analysis.Is_Null (Verified_Subprogram)
        or else Inside_Verified_Subprogram (Decl)
        or else Call.P_Is_Dispatching_Call
        or else not Effective_SPARK_Enabled (Decl)
      then
         return Symbols;
      end if;

      --  The postcondition is on the declaration the call resolves to or,
      --  when that is a completion, on the declaration it completes: the
      --  one a precise resolution gives, and no other.
      if Decl.Kind = Libadalang.Common.Ada_Subp_Body then
         Part := Decl.As_Subp_Body.P_Decl_Part (Imprecise_Fallback => False);
      elsif Decl.Kind in Libadalang.Common.Ada_Null_Subp_Decl
                       | Libadalang.Common.Ada_Expr_Function
      then
         Part := Decl.As_Base_Subp_Body.P_Decl_Part;
      end if;
      if not Libadalang.Analysis.Is_Null (Part)
        and then Libadalang.Analysis.Ada_Node (Part) =
          Libadalang.Analysis.Ada_Node (Decl)
      then
         Part := Libadalang.Analysis.No_Basic_Decl;
      end if;

      Post := Decl.P_Get_Aspect_Spec_Expr
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text ("Post")));
      if Libadalang.Analysis.Is_Null (Post)
        and then not Libadalang.Analysis.Is_Null (Part)
      then
         Post := Part.P_Get_Aspect_Spec_Expr
           (Langkit_Support.Text.To_Unbounded_Text
              (Langkit_Support.Text.To_Text ("Post")));
      end if;
      if Libadalang.Analysis.Is_Null (Post)
        or else Calls_May_Change_State (Post)
        or else Calls_Something_Untrusted (Post)
      then
         return Symbols;
      end if;

      for Left of Call.P_Call_Params loop
         if Takes_Access (Libadalang.Analysis.Actual (Left))
           or else
             (Formal_Is_Writable (Libadalang.Analysis.Param (Left))
              and then not Note_Written (Libadalang.Analysis.Actual (Left)))
         then
            return Symbols;
         end if;
      end loop;
      --  One object named by two actuals, one of which the call writes:
      --  a fact about one formal is then a fact about the other.
      for Left of Call.P_Call_Params loop
         for Right of Call.P_Call_Params loop
            if Libadalang.Analysis.Ada_Node
                 (Libadalang.Analysis.Actual (Left)) /=
               Libadalang.Analysis.Ada_Node
                 (Libadalang.Analysis.Actual (Right))
              and then Formal_Is_Writable (Libadalang.Analysis.Param (Left))
              and then Shares_Object
                         (Libadalang.Analysis.Actual (Left),
                          Libadalang.Analysis.Actual (Right))
            then
               return Symbols;
            end if;
         end loop;
      end loop;

      Block_All (Decl);
      Block_All (Part);
      for Pair of Call.P_Call_Params loop
         declare
            Formal : constant Libadalang.Analysis.Ada_Node :=
              Libadalang.Analysis.Ada_Node (Libadalang.Analysis.Param (Pair));
            Actual : constant Libadalang.Analysis.Expr'Class :=
              Libadalang.Analysis.Actual (Pair);
            Twin   : constant Libadalang.Analysis.Ada_Node :=
              (if Libadalang.Analysis.Is_Null (Part)
               then Libadalang.Analysis.No_Ada_Node
               else Formal_Named (Part, Normalized_Text (Formal)));
            Usable : constant Boolean :=
              (if Formal_Is_Writable (Libadalang.Analysis.Param (Pair))
               then Actual.Kind = Libadalang.Common.Ada_Identifier
               else Unchanged (Actual));
         begin
            if Usable then
               VC.Bind_Formal (Frame, Result, Formal, Actual, After);
               if not Libadalang.Analysis.Is_Null (Twin)
                 and then Twin /= Formal
               then
                  VC.Bind_Formal (Frame, Result, Twin, Actual, After);
               end if;
            end if;
         end;
      end loop;

      declare
         Assumed : constant VC.Symbolic_State :=
           VC.Assume_In_Frame (Result, Frame, Post, After);
      begin
         return (if VC.Equal (Assumed, VC.Havoc) then Symbols else Assumed);
      end;
   exception
      when others =>
         return Symbols;
   end With_Call_Postcondition;

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
      when Exc : others =>
         Log_Verbose_Once
           ("skipping formal-value seeding: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Seed_Formal_Values;

   function Contains_VC_Arithmetic
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;

   procedure Check_Call_Precondition
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Call    : Libadalang.Analysis.Name'Class;
      State   : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final   : Boolean := False)
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
         Contract_State : Flow_State := State;
         Contract_Symbols : VC.Symbolic_State := Symbols;
      begin
         if Libadalang.Analysis.Is_Null (Pre) then
            return;
         end if;

         --  The precondition is evaluated where the call is, so what the
         --  caller knows about the objects it names -- globals, most of
         --  all -- applies. The formals are the callee's own: on a
         --  recursive call they are the very names the caller's state
         --  describes, so each starts from nothing before it is given its
         --  actual's value. If the formals cannot be enumerated, nothing
         --  of the caller's state is used.
         begin
            for Pair of Call.P_Call_Params loop
               Flow_Havoc
                 (Contract_State,
                  Libadalang.Analysis.Ada_Node
                    (Libadalang.Analysis.Param (Pair)));
            end loop;
         exception
            when others =>
               Contract_State := Empty_Flow_State;
         end;

         Seed_Formal_Values
           (Call, State, Include_Outputs => True,
            Contract_State => Contract_State);
         for Pair of Call.P_Call_Params loop
            Contract_Symbols :=
              VC.Bind_Actual
                (Contract_Symbols,
                 Libadalang.Analysis.Ada_Node
                   (Libadalang.Analysis.Param (Pair)),
                 Libadalang.Analysis.Actual (Pair), State);
         end loop;

         --  When the call resolves to a completion (a body, a null
         --  procedure, an expression function), the precondition is written
         --  on the earlier declaration and names that declaration's
         --  formals, which are other defining names than the completion's.
         --  Each gets what its namesake was just given.
         declare
            Part : constant Libadalang.Analysis.Basic_Decl :=
              Contract_Part (Decl);
         begin
            if not Libadalang.Analysis.Is_Null (Part) then
               for Pair of Call.P_Call_Params loop
                  declare
                     Formal : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node
                         (Libadalang.Analysis.Param (Pair));
                     Twin   : constant Libadalang.Analysis.Ada_Node :=
                       Formal_Named (Part, Normalized_Text (Formal));
                  begin
                     if not Libadalang.Analysis.Is_Null (Twin)
                       and then Twin /= Formal
                     then
                        Flow_Copy_Key (Contract_State, Formal, Twin);
                        Contract_Symbols :=
                          VC.Bind_Actual
                            (Contract_Symbols, Twin,
                             Libadalang.Analysis.Actual (Pair), State);
                     end if;
                  end;
               end loop;
            end if;
         end;

         declare
            Value : constant Abstract_Bool :=
              Boolean_Value (Pre, Contract_State);
            VC_Outcome : constant VC.VC_Outcome :=
              (if Config.Verification_Mode and then Value = Bool_Unknown
               then VC.Decide
                 (Pre, Contract_State, Contract_Symbols)
               else VC.Unknown_Outcome);
            VC_Result : constant VC.VC_Result := VC_Outcome.Result;
         begin
            if Value = Bool_False
              or else
                (VC_Result = VC.VC_Refuted
                 and then not Contains_VC_Arithmetic (Pre))
            then
               Record_Definite_Error
                 (Unit, Call, Proof.Precondition_Check,
                  (if VC_Result = VC.VC_Refuted
                   then Proof.External_Prover else Proof.Contract_Transfer),
                  "actual arguments make the precondition false",
                  (if VC_Result = VC.VC_Refuted
                   then VC.Evidence else "precondition => false"),
                  Final => Final);
               Report_Flow_Violation
                 (Unit, Call, Rules.Known_Precondition_Failure,
                  "actual arguments make the precondition false",
                  Explanation =>
                    "The actual arguments were substituted for the formal " &
                    "parameters and the precondition evaluated to False.",
                  Evidence =>
                    (if VC_Result = VC.VC_Refuted
                     then VC.Evidence else "precondition => false"));
            elsif Config.Verification_Mode
              and then
                (Value = Bool_True or else VC_Result = VC.VC_Proved)
            then
               --  proof-path: precondition-decision
               Record_Proved_Safe
                 (Unit, Call, Proof.Precondition_Check,
                  (if VC_Result = VC.VC_Proved
                   then Proof.External_Prover else Proof.Contract_Transfer),
                  "actual arguments satisfy the precondition",
                  (if VC_Result = VC.VC_Proved
                   then VC.Evidence else "precondition => true"),
                  Final => Final);
            else
               Record_VC_Unproved
                 (Unit, Call, Proof.Precondition_Check,
                  Proof.Contract_Transfer,
                  "precondition failure is not established, but absence is " &
                    "not proved",
                  "current contract transfer does not certify safety",
                  VC_Outcome,
                  Final => Final);
            end if;
         end;
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
   --
   --  An unresolved callee, or a resolved one with no Global contract at
   --  all, gives no basis for naming which outside state it may write:
   --  ordinary (non-SPARK-annotated) Ada falls in this case for almost
   --  every call. Trusting prior knowledge to survive such a call is
   --  unsound (a value known before the call could have been changed by
   --  it, including through an up-level reference the caller never passes
   --  as a parameter), so this discards every tracked binding instead of
   --  leaving them untouched.
   procedure Havoc_Global_Effects
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      if Adalang_Analyzer.Subprogram_Summaries.Callee_State_Effects_Known
           (Call)
      then
         for Index in 1 ..
           Adalang_Analyzer.Subprogram_Summaries.Callee_Global_Write_Count
             (Call)
         loop
            Havoc_Object_Key
              (State,
               Adalang_Analyzer.Subprogram_Summaries.Callee_Global_Write
                 (Call, Index));
         end loop;
         return;
      end if;

      if Libadalang.Analysis.Is_Null (Decl) then
         Flow_Havoc_All (State);
         return;
      elsif Decl.Kind in Libadalang.Common.Ada_Synthetic_Subp_Decl
                       | Libadalang.Common.Ada_Enum_Literal_Decl
                       | Libadalang.Common.Ada_Synthetic_Char_Enum_Lit
        or else Function_Declared_Pure (Decl)
      then
         --  A predefined operator or attribute function ("T'Pos (X)"), a
         --  literal, or a function declared free of side effects.
         return;
      end if;

      declare
         Global : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Decl, "Global");
      begin
         if Libadalang.Analysis.Is_Null (Global) then
            Flow_Havoc_All (State);
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
      when Exc : others =>
         Log_Verbose_Once
           ("skipping Global-effect interpretation: " &
            Ada.Exceptions.Exception_Message (Exc));
         Flow_Havoc_All (State);
   end Havoc_Global_Effects;

   procedure Havoc_Call_Actuals
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
   begin
      for Pair of Call.P_Call_Params loop
         if Formal_Is_Writable (Libadalang.Analysis.Param (Pair))
           and then
             (not Adalang_Analyzer.Subprogram_Summaries
                    .Callee_State_Effects_Known (Call)
              or else Adalang_Analyzer.Subprogram_Summaries
                .Callee_Formal_May_Write
                  (Call, Libadalang.Analysis.Param (Pair)))
         then
            Havoc_Identifiers_In
              (Libadalang.Analysis.Actual (Pair), State);
         end if;

         if Adalang_Analyzer.Subprogram_Summaries
              .Callee_Formal_Definitely_Writes
                (Call, Libadalang.Analysis.Param (Pair))
           and then Libadalang.Analysis.Actual (Pair).Kind =
             Libadalang.Common.Ada_Identifier
         then
            Flow_Set_Initialized
              (State,
               Flow_Referenced_Name (Libadalang.Analysis.Actual (Pair)),
               Bool_True);
         end if;
      end loop;
   exception
      when others =>
         Havoc_Identifiers_In (Call, State);
   end Havoc_Call_Actuals;

   function Call_Transfer_Supported
     (Call : Libadalang.Analysis.Name'Class) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      if Libadalang.Analysis.Is_Null (Decl)
        or else not Effective_SPARK_Enabled (Decl)
        or else not Has_Aspect (Decl, "Global")
      then
         return False;
      end if;

      for Left of Call.P_Call_Params loop
         if Formal_Is_Writable (Libadalang.Analysis.Param (Left))
           and then Libadalang.Analysis.Actual (Left).Kind /=
             Libadalang.Common.Ada_Identifier
         then
            return False;
         end if;

         for Right of Call.P_Call_Params loop
            if (Formal_Is_Writable (Libadalang.Analysis.Param (Left))
                or else
                Formal_Is_Writable (Libadalang.Analysis.Param (Right)))
              and then Libadalang.Analysis.Actual (Left).Kind =
                Libadalang.Common.Ada_Identifier
              and then Libadalang.Analysis.Actual (Right).Kind =
                Libadalang.Common.Ada_Identifier
              and then Libadalang.Analysis.Ada_Node
                (Libadalang.Analysis.Actual (Left)) /=
                Libadalang.Analysis.Ada_Node
                  (Libadalang.Analysis.Actual (Right))
              and then Flow_Referenced_Name
                (Libadalang.Analysis.Actual (Left)) =
                Flow_Referenced_Name (Libadalang.Analysis.Actual (Right))
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   exception
      when others =>
         return False;
   end Call_Transfer_Supported;

   procedure Apply_Call_Postcondition
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);

      procedure Apply_Simple_Facts
        (Expr : Libadalang.Analysis.Ada_Node'Class)
      is
      begin
         if Libadalang.Analysis.Is_Null (Expr)
           or else Expr.Kind not in Libadalang.Common.Ada_Bin_Op_Range
           or else Is_User_Operator (Expr)
         then
            return;
         end if;

         declare
            Op : constant Libadalang.Analysis.Bin_Op := Expr.As_Bin_Op;
         begin
            if Op.F_Op in Libadalang.Common.Ada_Op_And
                | Libadalang.Common.Ada_Op_And_Then
            then
               Apply_Simple_Facts (Op.F_Left);
               Apply_Simple_Facts (Op.F_Right);
               return;
            elsif Op.F_Op /= Libadalang.Common.Ada_Op_Eq then
               return;
            end if;

            declare
               Formal_Expr : constant Libadalang.Analysis.Expr :=
                 (if Op.F_Left.Kind = Libadalang.Common.Ada_Identifier
                  then Op.F_Left
                  elsif Op.F_Right.Kind = Libadalang.Common.Ada_Identifier
                  then Op.F_Right
                  else Libadalang.Analysis.No_Expr);
               Fact_Expr : constant Libadalang.Analysis.Expr :=
                 (if Libadalang.Analysis.Is_Null (Formal_Expr)
                  then Libadalang.Analysis.No_Expr
                  elsif Libadalang.Analysis.Ada_Node (Formal_Expr) =
                    Libadalang.Analysis.Ada_Node (Op.F_Left)
                  then Op.F_Right
                  else Op.F_Left);
               Fact_Value : constant Abstract_Int :=
                 Integer_Value (Fact_Expr, State);
               Fact_Bool : constant Abstract_Bool :=
                 Boolean_Value (Fact_Expr, State);
            begin
               if Libadalang.Analysis.Is_Null (Formal_Expr) then
                  return;
               end if;

               for Pair of Call.P_Call_Params loop
                  if Normalized_Text (Libadalang.Analysis.Param (Pair)) =
                    Normalized_Text (Formal_Expr)
                    and then Formal_Is_Writable
                      (Libadalang.Analysis.Param (Pair))
                    and then Libadalang.Analysis.Actual (Pair).Kind =
                      Libadalang.Common.Ada_Identifier
                  then
                     declare
                        Key : constant Libadalang.Analysis.Ada_Node :=
                          Flow_Referenced_Name
                            (Libadalang.Analysis.Actual (Pair));
                     begin
                        if Fact_Value.Known then
                           Flow_Set (State, Key, Fact_Value);
                           Flow_Range_Set
                             (State, Key, Range_From_Int (Fact_Value));
                        end if;
                        if Fact_Bool /= Bool_Unknown then
                           Flow_Bool_Set (State, Key, Fact_Bool);
                        end if;
                        Flow_Set_Initialized (State, Key, Bool_True);
                     end;
                  end if;
               end loop;
            end;
         end;
      end Apply_Simple_Facts;
   begin
      if Libadalang.Analysis.Is_Null (Decl)
        or else not Effective_SPARK_Enabled (Decl)
        or else
          (Config.Verification_Mode
           and then not Call_Transfer_Supported (Call))
      then
         if Config.Verification_Mode then
            Log_Verbose_Once
              ("not applying unsupported call postcondition transfer at " &
               Ada_Text.Node_Text (Call));
         end if;
         return;
      end if;

      declare
         Post : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Decl, "Post");
         Contract_State : Flow_State := Empty_Flow_State;
         True_State, False_State : Flow_State;
         Says_Nothing : Boolean;
      begin
         if Libadalang.Analysis.Is_Null (Post) then
            return;
         end if;

         Seed_Formal_Values
           (Call, State, Include_Outputs => False,
            Contract_State => Contract_State);
         --  What a postcondition says before it calls something that
         --  changes state need not hold after it (FP-109): such a
         --  postcondition gives no fact. The actuals the call writes are
         --  still set below, to the nothing that is then known of them.
         Says_Nothing := Calls_May_Change_State (Post);
         if Says_Nothing then
            True_State := Contract_State;
         else
            Narrow_By_Condition
              (Post, Contract_State, True_State, False_State);
            if Boolean_Value (Post, Contract_State) = Bool_False then
               return;
            end if;
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
         if not Says_Nothing then
            Apply_Simple_Facts (Post);
         end if;
      end;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping postcondition interpretation: " &
            Ada.Exceptions.Exception_Message (Exc));
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
            if Node.As_Call_Expr.P_Kind = Libadalang.Common.Call then
               Havoc_Global_Effects (Node.As_Call_Expr.F_Name, State);
               Havoc_Call_Actuals (Node.As_Call_Expr.F_Name, State);
            else
               for Index in 1 .. Node.Children_Count loop
                  Havoc_Effects_In (Node.Child (Index), State);
               end loop;
            end if;
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

   --  Type_Range and Array_Index_Range moved to Adalang_Analyzer.Flow_Eval
   --  (still visible here unqualified via this unit's own "use
   --  Adalang_Analyzer.Flow_Eval") so Adalang_Analyzer.VC_Prover, which sits
   --  below this unit and cannot import it, can resolve subtype-mark and
   --  array-attribute bounds too -- see VC_Prover's Ada_Membership_Expr and
   --  Ada_Attribute_Ref support.

   function Definitely_Outside_Range
     (Value        : Libadalang.Analysis.Expr'Class;
      Target_Range : Abstract_Range;
      State        : Flow_State) return Boolean
   is
      Value_Bounds : constant Abstract_Range := Range_Value (Value, State);
   begin
      return
        (Value_Bounds.Has_High
         and then Target_Range.Has_Low
         and then Value_Bounds.High < Target_Range.Low)
        or else
        (Value_Bounds.Has_Low
         and then Target_Range.Has_High
         and then Value_Bounds.Low > Target_Range.High);
   end Definitely_Outside_Range;

   function Definitely_Inside_Range
     (Value  : Libadalang.Analysis.Ada_Node'Class;
      Bounds : Abstract_Range;
      State  : Flow_State) return Boolean
   is
      Value_Bounds : constant Abstract_Range := Range_Value (Value, State);
   begin
      return Bounds.Has_Low
        and then Bounds.Has_High
        and then Value_Bounds.Has_Low
        and then Value_Bounds.Has_High
        and then Value_Bounds.Low >= Bounds.Low
        and then Value_Bounds.High <= Bounds.High;
   end Definitely_Inside_Range;

   function Definitely_Outside_Type
     (Value : Libadalang.Analysis.Expr'Class;
      Typ   : Libadalang.Analysis.Base_Type_Decl;
      State : Flow_State) return Boolean
   is
      Type_Bounds  : constant Abstract_Range := Type_Range (Typ, State);
   begin
      return Definitely_Outside_Range (Value, Type_Bounds, State);
   exception
      when others =>
         return False;
   end Definitely_Outside_Type;

   function Definitely_Inside_Type
     (Value : Libadalang.Analysis.Ada_Node'Class;
      Typ   : Libadalang.Analysis.Base_Type_Decl;
      State : Flow_State) return Boolean
   is
      Type_Bounds : constant Abstract_Range := Type_Range (Typ, State);
   begin
      if Value.Kind = Libadalang.Common.Ada_Call_Expr
        and then Value.As_Call_Expr.P_Kind =
          Libadalang.Common.Type_Conversion
      then
         declare
            Converted_Type : constant Libadalang.Analysis.Basic_Decl :=
              Value.As_Call_Expr.F_Name.P_Referenced_Decl;
         begin
            if not Libadalang.Analysis.Is_Null (Converted_Type)
              and then Converted_Type.Kind in
                Libadalang.Common.Ada_Base_Type_Decl
              and then Libadalang.Analysis.Ada_Node
                (Converted_Type.As_Base_Type_Decl) =
                Libadalang.Analysis.Ada_Node (Typ)
            then
               return True;
            end if;
         end;
      end if;
      return Definitely_Inside_Range (Value, Type_Bounds, State);
   exception
      when others =>
         return False;
   end Definitely_Inside_Type;

   function Overflow_Base_Range
     (Typ   : Libadalang.Analysis.Base_Type_Decl'Class;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Abstract_Range
   is
      --  A single P_Base_Type hop only reaches the immediate parent, whose
      --  own visible constraint can itself be a narrowed first subtype
      --  (e.g. a "new Natural" parent still carries Natural's 0-based
      --  constraint, not its own unconstrained base range). Walk to the
      --  derivation root instead, so a multiply-derived type (RecordFlux's
      --  Index -> Length -> Natural pattern, for instance) resolves to its
      --  true machine base range. Only do this when a real parent exists:
      --  Is_Null also covers non-derived types and Libadalang's synthetic
      --  universal-integer root (named-number initializers such as a bare
      --  "2**14"), neither of which has a real base range to widen to --
      --  the latter's own visible "range" is a meaningless placeholder.
      Immediate_Base : constant Libadalang.Analysis.Base_Type_Decl :=
        Typ.P_Base_Type (Node);
   begin
      if not Libadalang.Analysis.Is_Null (Immediate_Base) then
         return Type_Range (Typ.P_Root_Type (Node), State);
      end if;

      --  Not a derived type, but Typ's own declared range can still be a
      --  dynamic constraint layered on an otherwise statically-bounded
      --  named type (e.g. "Rnd_Len : size_t range Rnd_Buffer'First ..
      --  Rnd_Buffer'Length", where Rnd_Buffer is an unconstrained array
      --  parameter, so the constraint itself has no static bounds).
      --  Ada scalar subtyping only ever narrows a type's range, so
      --  falling back to Typ's own fully-unwound base subtype -- which
      --  P_Base_Subtype already recurses through any further subtype
      --  chain to reach -- is always a sound, if looser,
      --  overapproximation: a wider bound, never a wrong one.
      declare
         Base_Subtype : constant Libadalang.Analysis.Base_Type_Decl :=
           Typ.P_Base_Subtype (Node);
      begin
         if Libadalang.Analysis.Is_Null (Base_Subtype)
           or else Libadalang.Analysis.Ada_Node (Base_Subtype) =
             Libadalang.Analysis.Ada_Node (Typ)
         then
            return Unknown_Range;
         end if;
         return Type_Range (Base_Subtype, State);
      end;
   end Overflow_Base_Range;

   function Arithmetic_Proved_Safe
     (Node  : Libadalang.Analysis.Expr'Class;
      State : Flow_State) return Boolean
   is
      Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
        Node.P_Expression_Type;
   begin
      if Libadalang.Analysis.Is_Null (Expr_Type)
        or else not Expr_Type.P_Is_Int_Type
      then
         return False;
      end if;

      declare
         Bounds : Abstract_Range :=
           Overflow_Base_Range (Expr_Type, Node, State);
         Name   : constant String := Langkit_Support.Text.To_UTF8
           (Expr_Type.P_Canonical_Fully_Qualified_Name);
      begin
         if not Bounds.Has_Low
           and then not Bounds.Has_High
           and then Name = "standard.integer"
         then
            Bounds := Type_Range (Expr_Type, State);
         end if;
         return Definitely_Inside_Range (Node, Bounds, State);
      end;
   exception
      when others =>
         return False;
   end Arithmetic_Proved_Safe;

   function Known_Arithmetic_Overflow
     (Node  : Libadalang.Analysis.Expr'Class;
      State : Flow_State) return Boolean
   is
   begin
      if Node.Kind not in Libadalang.Common.Ada_Bin_Op_Range
        or else Node.As_Bin_Op.F_Op not in
          Libadalang.Common.Ada_Op_Plus
            | Libadalang.Common.Ada_Op_Minus
            | Libadalang.Common.Ada_Op_Mult
            | Libadalang.Common.Ada_Op_Div
            | Libadalang.Common.Ada_Op_Pow
      then
         return False;
      end if;

      declare
         Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Node.P_Expression_Type;
      begin
         if Libadalang.Analysis.Is_Null (Expr_Type)
           or else not Expr_Type.P_Is_Int_Type
         then
            return False;
         end if;

         declare
            Bounds : Abstract_Range :=
              Overflow_Base_Range (Expr_Type, Node, State);
            Name   : constant String := Langkit_Support.Text.To_UTF8
              (Expr_Type.P_Canonical_Fully_Qualified_Name);
         begin
            --  Standard.Integer's base subtype is synthetic and its bound
            --  expressions are not always reducible by the evaluator. Its
            --  visible declaration has the same bounds, so it is a sound
            --  fallback. Do not apply this fallback to derived first
            --  subtypes: their visible constraint can be narrower than the
            --  operation's base range.
            if not Bounds.Has_Low
              and then not Bounds.Has_High
              and then Name = "standard.integer"
            then
               Bounds := Type_Range (Expr_Type, State);
            end if;
            return Definitely_Outside_Range (Node, Bounds, State);
         end;
      end;
   exception
      when others =>
         return False;
   end Known_Arithmetic_Overflow;

   --  As Known_Arithmetic_Overflow, when it takes the scalar verification
   --  condition to establish the overflow: the decision
   --  Check_Integer_Overflow reports as a definite error.
   function Arithmetic_Overflow_Refuted
     (Node    : Libadalang.Analysis.Expr'Class;
      State   : Flow_State;
      Symbols : VC.Symbolic_State) return Boolean
   is
   begin
      if Node.Kind not in Libadalang.Common.Ada_Bin_Op_Range
        or else Node.As_Bin_Op.F_Op not in
          Libadalang.Common.Ada_Op_Plus
            | Libadalang.Common.Ada_Op_Minus
            | Libadalang.Common.Ada_Op_Mult
            | Libadalang.Common.Ada_Op_Div
            | Libadalang.Common.Ada_Op_Pow
      then
         return False;
      end if;

      declare
         Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Node.P_Expression_Type;
      begin
         if Libadalang.Analysis.Is_Null (Expr_Type)
           or else not Expr_Type.P_Is_Int_Type
           or else Arithmetic_Proved_Safe (Node, State)
         then
            return False;
         end if;

         declare
            Bounds : Abstract_Range :=
              Overflow_Base_Range (Expr_Type, Node, State);
            Name   : constant String := Langkit_Support.Text.To_UTF8
              (Expr_Type.P_Canonical_Fully_Qualified_Name);
         begin
            if not Bounds.Has_Low
              and then not Bounds.Has_High
              and then Name = "standard.integer"
            then
               Bounds := Type_Range (Expr_Type, State);
            end if;
            return VC.Decide_Bounds (Node, Bounds, State, Symbols).Result =
              VC.VC_Refuted;
         end;
      end;
   exception
      when others =>
         return False;
   end Arithmetic_Overflow_Refuted;

   procedure Check_Value_Range
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Value   : Libadalang.Analysis.Expr'Class;
      Typ     : Libadalang.Analysis.Base_Type_Decl;
      State   : Flow_State;
      Rule    : Rules.Rule_Kind;
      Message : String;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final   : Boolean := False;
      Constraint : Subtype_Constraint := (others => <>))
   is
      --  The range the value must be in: that of Typ, or that of the
      --  constraint the target's own declaration adds to it (FP-107).
      function Target_Range return Abstract_Range
      is (if Constraint.Present then Constraint.Bounds
          else Type_Range (Typ, State));

      function Outside_Target return Boolean
      is (Definitely_Outside_Type (Value, Typ, State)
          or else
            (Constraint.Present
             and then Definitely_Outside_Range
                        (Value, Constraint.Bounds, State)));

      function Inside_Target return Boolean
      is (if Constraint.Present
          then Definitely_Inside_Range (Value, Constraint.Bounds, State)
          else Definitely_Inside_Type (Value, Typ, State));
   begin
      if Config.Rule_States (Rule) /= Config.Enabled then
         return;
      end if;

      --  A definitely overflowing expression raises before the subsequent
      --  subtype check. Do not create a second obligation for an operation
      --  that is not reached on the represented execution.
      if Rule = Rules.Known_Range_Check_Failure
        and then Config.Rule_States (Rules.Known_Overflow_Failure) =
          Config.Enabled
        and then Known_Arithmetic_Overflow (Value, State)
      then
         return;
      elsif Libadalang.Analysis.Is_Null (Typ) then
         if Config.Verification_Mode then
            Record_Unsupported
              (Unit, Value, Proof.Range_Check,
               "target subtype could not be resolved");
         else
            Record_Unproved
              (Unit, Value, Proof.Range_Check, Proof.No_Analysis,
               "target subtype could not be resolved",
               Imprecision => "semantic type resolution failed");
         end if;
      elsif Outside_Target then
         Record_Definite_Error
           (Unit, Value, Proof.Range_Check, Proof.Abstract_Interpretation,
            Message, "value range is outside the target subtype range",
            Final => Final);
         Report_Flow_Violation
           (Unit, Value, Rule, Message,
            Explanation =>
              "Abstract interpretation found that every represented value " &
              "is outside the target subtype range.",
            Evidence => "value range is outside the target subtype range");
      elsif Config.Verification_Mode then
         if Inside_Target then
            --  proof-path: range-abstract
            Record_Proved_Safe
              (Unit, Value, Proof.Range_Check, Proof.Abstract_Interpretation,
               "value range is contained in the target subtype range",
               "value bounds are within target bounds", Final => Final);
         else
            declare
               Outcome : constant VC.VC_Outcome :=
                 VC.Decide_Bounds (Value, Target_Range, State, Symbols);
            begin
               case Outcome.Result is
                  when VC.VC_Proved =>
                     --  proof-path: range-external
                     Record_Proved_Safe
                       (Unit, Value, Proof.Range_Check,
                        Proof.External_Prover,
                        "scalar verification condition proves the value is " &
                          "inside the target subtype range",
                        VC.Evidence, Final => Final);
                  when VC.VC_Refuted =>
                     --  The verification condition computes without
                     --  overflow, so it also refutes the range of a value
                     --  that is never produced because computing it always
                     --  overflows. As above, that is the overflow check's
                     --  error, not a second one here (FP-100).
                     if Rule /= Rules.Known_Range_Check_Failure
                       or else Config.Rule_States
                                 (Rules.Known_Overflow_Failure) /=
                         Config.Enabled
                       or else not Arithmetic_Overflow_Refuted
                                     (Value, State, Symbols)
                     then
                        Record_Definite_Error
                          (Unit, Value, Proof.Range_Check,
                           Proof.External_Prover, Message, VC.Evidence,
                           Final => Final);
                        Report_Flow_Violation
                          (Unit, Value, Rule, Message,
                           Explanation =>
                             "The scalar verification condition " &
                             "establishes that the value cannot satisfy " &
                             "the target subtype bounds.",
                           Evidence => VC.Evidence);
                     end if;
                  when others =>
                     Record_VC_Unproved
                       (Unit, Value, Proof.Range_Check,
                        Proof.Abstract_Interpretation,
                        "range-check failure is not established, but " &
                          "absence is not proved",
                        "the current non-relational range domain is " &
                          "inconclusive",
                        Outcome, Final => Final);
               end case;
            end;
         end if;
      else
         Record_Unproved
           (Unit, Value, Proof.Range_Check, Proof.Abstract_Interpretation,
            "range-check failure is not established, but absence is not " &
              "proved",
            Imprecision =>
              "the current non-relational range domain is inconclusive",
            Final => Final);
      end if;
   end Check_Value_Range;

   function Assoc_Expression
     (List : Libadalang.Analysis.Ada_Node'Class;
      Index : Positive) return Libadalang.Analysis.Expr is
   begin
      if Libadalang.Analysis.Is_Null (List) then
         return Libadalang.Analysis.No_Expr;
      end if;

      --  Libadalang represents a single positional suffix directly as an
      --  expression, and uses an association list for multiple or named
      --  actuals/indices.
      if List.Kind in Libadalang.Common.Ada_Expr then
         return
           (if Index = 1 then List.As_Expr
            else Libadalang.Analysis.No_Expr);
      elsif List.Children_Count < Index then
         return Libadalang.Analysis.No_Expr;
      end if;
      if List.Child (Index).Kind = Libadalang.Common.Ada_Param_Assoc then
         return List.Child (Index).As_Param_Assoc.F_R_Expr;
      elsif List.Child (Index).Kind in Libadalang.Common.Ada_Base_Assoc then
         return List.Child (Index).As_Base_Assoc.P_Assoc_Expr;
      else
         return Libadalang.Analysis.No_Expr;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Assoc_Expression;

   --  The declaration whose range is the base range of the integer type
   --  Typ: the nearest type or subtype Typ is declared from that has every
   --  value of its type (see Covers_Its_Type). None when no declaration
   --  says what the base range is, as for "type T is range 1 .. 10", for
   --  which the implementation chooses it.
   function Base_Range_Type
     (Typ : Libadalang.Analysis.Base_Type_Decl)
      return Libadalang.Analysis.Base_Type_Decl
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            exit;
         elsif Covers_Its_Type (Current) then
            return Current;
         elsif Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            Current :=
              Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
         elsif Current.Kind in Libadalang.Common.Ada_Type_Decl
           and then not Libadalang.Analysis.Is_Null
                          (Current.As_Type_Decl.F_Type_Def)
           and then Current.As_Type_Decl.F_Type_Def.Kind =
             Libadalang.Common.Ada_Derived_Type_Def
         then
            Current :=
              Current.As_Type_Decl.F_Type_Def.As_Derived_Type_Def
                .F_Subtype_Indication.P_Designated_Type_Decl;
         else
            exit;
         end if;
      end loop;
      return Libadalang.Analysis.No_Base_Type_Decl;
   exception
      when others =>
         return Libadalang.Analysis.No_Base_Type_Decl;
   end Base_Range_Type;

   --  The values the base range of the integer type Typ has whatever the
   --  implementation chooses for it: those of the range the type is
   --  declared with, a base range having them all and being symmetric
   --  about zero, but for one more negative value at most (RM 3.5.4 (9)).
   --  Unknown_Range unless Typ is declared from a signed integer type
   --  definition with static bounds.
   function Least_Base_Range
     (Typ : Libadalang.Analysis.Base_Type_Decl) return Abstract_Range
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
      Declared  : Abstract_Range;
      Last      : Long_Long_Integer;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            exit;
         elsif Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            Current :=
              Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
         elsif Current.Kind not in Libadalang.Common.Ada_Type_Decl
           or else Libadalang.Analysis.Is_Null
                     (Current.As_Type_Decl.F_Type_Def)
         then
            exit;
         elsif Current.As_Type_Decl.F_Type_Def.Kind =
           Libadalang.Common.Ada_Derived_Type_Def
         then
            Current :=
              Current.As_Type_Decl.F_Type_Def.As_Derived_Type_Def
                .F_Subtype_Indication.P_Designated_Type_Decl;
         elsif Current.As_Type_Decl.F_Type_Def.Kind =
           Libadalang.Common.Ada_Signed_Int_Type_Def
         then
            Declared := Type_Range (Current, Empty_Flow_State);
            if not Declared.Has_Low or else not Declared.Has_High
              or else Declared.Low > Declared.High
            then
               exit;
            end if;
            Last :=
              Long_Long_Integer'Max (Declared.High, -(Declared.Low + 1));
            return
              (Has_Low  => True,
               Low      => Long_Long_Integer'Min (Declared.Low, -Last),
               Has_High => True,
               High     => Last);
         else
            exit;
         end if;
      end loop;
      return Unknown_Range;
   exception
      when others =>
         return Unknown_Range;
   end Least_Base_Range;

   --  The number of dimensions of the array type Typ, and zero when it is
   --  not one.
   function Array_Dimensions
     (Typ : Libadalang.Analysis.Base_Type_Decl) return Natural
   is
      Max_Dimensions : constant := 8;
      Count          : Natural := 0;
   begin
      if Libadalang.Analysis.Is_Null (Typ) or else not Typ.P_Is_Array_Type
      then
         return 0;
      end if;

      for Dimension in 0 .. Max_Dimensions - 1 loop
         begin
            exit when Libadalang.Analysis.Is_Null
                        (Typ.P_Index_Type (Dimension));
         exception
            when others =>
               exit;
         end;
         Count := Count + 1;
      end loop;
      return Count;
   exception
      when others =>
         return 0;
   end Array_Dimensions;

   --  The number of values of Bounds when both of them are known.
   function Range_Length (Bounds : Abstract_Range) return Abstract_Int is
      Span : Abstract_Int;
   begin
      if not Bounds.Has_Low or else not Bounds.Has_High then
         return Unknown_Int;
      elsif Bounds.Low > Bounds.High then
         return Known_Int (0);
      end if;
      Span := Safe_Sub (Bounds.High, Bounds.Low);
      return (if Span.Known then Safe_Add (Span.Value, 1) else Unknown_Int);
   end Range_Length;

   --  The bounds a declaration fixes for the Dimension-th index of what
   --  Prefix names: an array object or component, a constrained array
   --  subtype, or, for the first, an integer subtype.
   function Fixed_Bounds
     (Prefix    : Libadalang.Analysis.Name'Class;
      Dimension : Positive) return Abstract_Range
   is
      Decl : Libadalang.Analysis.Basic_Decl :=
        Libadalang.Analysis.No_Basic_Decl;
   begin
      if Prefix.Kind in Libadalang.Common.Ada_Identifier
                      | Libadalang.Common.Ada_Dotted_Name
      then
         Decl := Prefix.P_Referenced_Decl;
      end if;

      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind not in Libadalang.Common.Ada_Base_Type_Decl
      then
         return Array_Object_Index_Range
           (Prefix, Dimension, Empty_Flow_State);
      elsif Decl.As_Base_Type_Decl.P_Is_Array_Type then
         return Array_Index_Range
           (Decl.As_Base_Type_Decl, Dimension, Empty_Flow_State);
      elsif Dimension = 1 then
         return Type_Range (Decl.As_Base_Type_Decl, Empty_Flow_State);
      end if;
      return Unknown_Range;
   exception
      when others =>
         return Unknown_Range;
   end Fixed_Bounds;

   --  The value of Item when it is a static expression: one the analysis
   --  folds, one a compiler does, a bound or the length of an array whose
   --  bounds a declaration fixes, or a sum or a difference of such.
   function Static_Integer
     (Item : Libadalang.Analysis.Expr'Class) return Abstract_Int
   is
      --  What Libadalang evaluates, when it takes Item for static.
      function Evaluated return Abstract_Int is
      begin
         if Item.P_Is_Static_Expr then
            return Known_Int
              (Long_Long_Integer'Value
                 (GNATCOLL.GMP.Integers.Image (Item.P_Eval_As_Int)));
         end if;
         return Unknown_Int;
      exception
         when others =>
            return Unknown_Int;
      end Evaluated;

      Folded : Abstract_Int;
   begin
      if Libadalang.Analysis.Is_Null (Item) then
         return Unknown_Int;
      elsif Item.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Static_Integer (Item.As_Paren_Expr.F_Expr);
      end if;

      Folded := Integer_Value (Item, Empty_Flow_State);
      if Folded.Known then
         return Folded;
      elsif Item.Kind = Libadalang.Common.Ada_Attribute_Ref then
         declare
            Attribute : constant Libadalang.Analysis.Attribute_Ref :=
              Item.As_Attribute_Ref;
            Name      : constant String :=
              Normalized_Text (Attribute.F_Attribute);
            Dimension : constant Abstract_Int :=
              (if Libadalang.Analysis.Is_Null (Attribute.F_Args)
                 or else Attribute.F_Args.Children_Count = 0
               then Known_Int (1)
               else Integer_Value
                      (Assoc_Expression (Attribute.F_Args, 1),
                       Empty_Flow_State));
            Bounds    : Abstract_Range := Unknown_Range;

            --  True when the prefix names an object or a subtype outright.
            --  A compiler folds the bounds of those; those of a component
            --  it leaves to be computed, static as its subtype may be.
            function Named_Outright return Boolean is
               Decl : Libadalang.Analysis.Basic_Decl;
            begin
               if Attribute.F_Prefix.Kind not in
                 Libadalang.Common.Ada_Identifier
                   | Libadalang.Common.Ada_Dotted_Name
               then
                  return False;
               end if;
               Decl := Attribute.F_Prefix.P_Referenced_Decl;
               return not Libadalang.Analysis.Is_Null (Decl)
                 and then
                   (Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
                      | Libadalang.Common.Ada_Object_Decl_Range
                    or else Decl.Kind = Libadalang.Common.Ada_Param_Spec);
            exception
               when others =>
                  return False;
            end Named_Outright;
         begin
            if Name in "first" | "last" | "length"
              and then Dimension.Known
              and then Dimension.Value in 1 .. 8
              and then Named_Outright
            then
               Bounds :=
                 Fixed_Bounds
                   (Attribute.F_Prefix, Positive (Dimension.Value));
            end if;
            --  Both bounds, or neither: an array with one bound that is
            --  not static has no static attribute, whatever the other is.
            if Bounds.Has_Low and then Bounds.Has_High then
               if Name = "length" then
                  return Range_Length (Bounds);
               elsif Name = "first" then
                  return Known_Int (Bounds.Low);
               elsif Name = "last" then
                  return Known_Int (Bounds.High);
               end if;
            end if;
         end;
      elsif Item.Kind = Libadalang.Common.Ada_Bin_Op
        and then Item.As_Bin_Op.F_Op.Kind in Libadalang.Common.Ada_Op_Plus
          | Libadalang.Common.Ada_Op_Minus
        and then Origin_Of_Operator (Item) = Predefined
      then
         declare
            Left  : constant Abstract_Int :=
              Static_Integer (Item.As_Bin_Op.F_Left);
            Right : constant Abstract_Int :=
              (if Left.Known then Static_Integer (Item.As_Bin_Op.F_Right)
               else Unknown_Int);
         begin
            if Right.Known then
               return
                 (if Item.As_Bin_Op.F_Op.Kind = Libadalang.Common.Ada_Op_Plus
                  then Safe_Add (Left.Value, Right.Value)
                  else Safe_Sub (Left.Value, Right.Value));
            end if;
         end;
      end if;
      return Evaluated;
   exception
      when others =>
         return Unknown_Int;
   end Static_Integer;

   --  The number of literals of the enumeration type that is the
   --  Dimension-th index of the constrained array type Typ, when that
   --  index is written as the name of the whole type: a length a compiler
   --  knows as well as one between two integer bounds.
   function Enumeration_Index_Length
     (Typ       : Libadalang.Analysis.Base_Type_Decl;
      Dimension : Positive) return Abstract_Int
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
      Index     : Libadalang.Analysis.Ada_Node;
      Named     : Libadalang.Analysis.Basic_Decl;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return Unknown_Int;
         elsif Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            if not Libadalang.Analysis.Is_Null
                     (Current.As_Subtype_Decl.F_Subtype.F_Constraint)
            then
               return Unknown_Int;
            end if;
            Current :=
              Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
         elsif Current.Kind in Libadalang.Common.Ada_Type_Decl
           and then not Libadalang.Analysis.Is_Null
                          (Current.As_Type_Decl.F_Type_Def)
           and then Current.As_Type_Decl.F_Type_Def.Kind =
             Libadalang.Common.Ada_Array_Type_Def
         then
            exit;
         else
            return Unknown_Int;
         end if;
      end loop;

      declare
         Indices : constant Libadalang.Analysis.Array_Indices :=
           Current.As_Type_Decl.F_Type_Def.As_Array_Type_Def.F_Indices;
      begin
         if Indices.Kind not in
              Libadalang.Common.Ada_Constrained_Array_Indices_Range
           or else Indices.As_Constrained_Array_Indices.F_List
             .Children_Count < Dimension
         then
            return Unknown_Int;
         end if;
         Index :=
           Indices.As_Constrained_Array_Indices.F_List.Child (Dimension);
      end;

      if Index.Kind in Libadalang.Common.Ada_Subtype_Indication_Range
        and then Libadalang.Analysis.Is_Null
                   (Index.As_Subtype_Indication.F_Constraint)
      then
         Named := Index.As_Subtype_Indication.F_Name.P_Referenced_Decl;
      elsif Index.Kind in Libadalang.Common.Ada_Identifier
                        | Libadalang.Common.Ada_Dotted_Name
      then
         Named := Index.As_Name.P_Referenced_Decl;
      else
         return Unknown_Int;
      end if;

      if not Libadalang.Analysis.Is_Null (Named)
        and then Named.Kind in Libadalang.Common.Ada_Type_Decl
        and then not Libadalang.Analysis.Is_Null
                       (Named.As_Type_Decl.F_Type_Def)
        and then Named.As_Type_Decl.F_Type_Def.Kind =
          Libadalang.Common.Ada_Enum_Type_Def
      then
         return Known_Int
           (Long_Long_Integer
              (Named.As_Type_Decl.F_Type_Def.As_Enum_Type_Def
                 .F_Enum_Literals.Children_Count));
      end if;
      return Unknown_Int;
   exception
      when others =>
         return Unknown_Int;
   end Enumeration_Index_Length;

   --  The length of the Dimension-th dimension of the constrained array
   --  subtype Typ, when its bounds are static.
   function Subtype_Array_Length
     (Typ       : Libadalang.Analysis.Base_Type_Decl;
      Dimension : Positive) return Abstract_Int
   is
      Counted : constant Abstract_Int :=
        Range_Length (Array_Index_Range (Typ, Dimension, Empty_Flow_State));
   begin
      return
        (if Counted.Known then Counted
         else Enumeration_Index_Length (Typ, Dimension));
   end Subtype_Array_Length;

   --  The subtype a declaration gives with Type_Expr: the type or subtype
   --  it names, none when there is nothing to name.
   function Designated_Type
     (Type_Expr : Libadalang.Analysis.Type_Expr'Class)
      return Libadalang.Analysis.Base_Type_Decl
   is
   begin
      if Libadalang.Analysis.Is_Null (Type_Expr) then
         return Libadalang.Analysis.No_Base_Type_Decl;
      end if;
      return Type_Expr.P_Designated_Type_Decl;
   exception
      when others =>
         return Libadalang.Analysis.No_Base_Type_Decl;
   end Designated_Type;

   --  True when Type_Expr adds an index constraint to the type it names.
   function Has_Index_Constraint
     (Type_Expr : Libadalang.Analysis.Type_Expr'Class) return Boolean
   is (not Libadalang.Analysis.Is_Null (Type_Expr)
       and then Type_Expr.Kind in
         Libadalang.Common.Ada_Subtype_Indication_Range
       and then not Libadalang.Analysis.Is_Null
                      (Type_Expr.As_Subtype_Indication.F_Constraint));

   --  The length of the Dimension-th dimension that an array subtype gives
   --  what is declared with it, when it gives one with static bounds: by
   --  the index constraint of Type_Expr, if there is one, or by the
   --  constrained array subtype Typ.
   function Declared_Array_Length
     (Typ       : Libadalang.Analysis.Base_Type_Decl;
      Type_Expr : Libadalang.Analysis.Type_Expr'Class;
      Dimension : Positive) return Abstract_Int
   is
   begin
      if Has_Index_Constraint (Type_Expr) then
         return Range_Length
           (Index_Constraint_Range
              (Type_Expr.As_Subtype_Indication.F_Constraint, Dimension,
               Empty_Flow_State));
      end if;
      return Subtype_Array_Length (Typ, Dimension);
   exception
      when others =>
         return Unknown_Int;
   end Declared_Array_Length;

   --  True when the array subtype Typ, with the constraint Type_Expr may
   --  add to it, is a constrained one: what is declared with it has the
   --  bounds it gives, static or not.
   function Is_Constrained_Array
     (Typ       : Libadalang.Analysis.Base_Type_Decl;
      Type_Expr : Libadalang.Analysis.Type_Expr'Class) return Boolean
   is
   begin
      if Array_Dimensions (Typ) = 0 then
         return False;
      end if;
      return Has_Index_Constraint (Type_Expr)
        or else Typ.P_Is_Definite_Subtype (Typ);
   exception
      when others =>
         return False;
   end Is_Constrained_Array;

   --  True when the array Target names has a constrained subtype of its
   --  own: a slice, a component, or an object or a formal parameter
   --  declared with one. An object or a formal of an unconstrained subtype
   --  has the bounds of its initial value or of its actual, and no subtype
   --  to convert a value to.
   function Target_Is_Constrained
     (Target : Libadalang.Analysis.Expr'Class) return Boolean
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Target) then
         return False;
      elsif Target.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Target_Is_Constrained (Target.As_Paren_Expr.F_Expr);
      elsif Target.Kind = Libadalang.Common.Ada_Call_Expr then
         return Target.As_Call_Expr.P_Kind in
           Libadalang.Common.Array_Slice | Libadalang.Common.Array_Index;
      elsif Target.Kind = Libadalang.Common.Ada_Explicit_Deref then
         return Target.P_Expression_Type.P_Is_Definite_Subtype (Target);
      elsif Target.Kind not in Libadalang.Common.Ada_Identifier
                             | Libadalang.Common.Ada_Dotted_Name
      then
         return False;
      end if;

      Decl := Target.As_Name.P_Referenced_Decl;
      if Libadalang.Analysis.Is_Null (Decl) then
         return False;
      elsif Decl.Kind = Libadalang.Common.Ada_Component_Decl then
         return True;
      elsif Decl.Kind = Libadalang.Common.Ada_Param_Spec then
         return Is_Constrained_Array
           (Designated_Type (Decl.As_Param_Spec.F_Type_Expr),
            Decl.As_Param_Spec.F_Type_Expr);
      elsif Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range then
         if not Libadalang.Analysis.Is_Null
                  (Decl.As_Object_Decl.F_Renaming_Clause)
         then
            return Target_Is_Constrained
              (Decl.As_Object_Decl.F_Renaming_Clause.F_Renamed_Object);
         end if;
         return Is_Constrained_Array
           (Designated_Type (Decl.As_Object_Decl.F_Type_Expr),
            Decl.As_Object_Decl.F_Type_Expr);
      end if;
      return False;
   exception
      when others =>
         return False;
   end Target_Is_Constrained;

   --  The aggregate that gives the Dimension-th dimension of the array
   --  aggregate Value its components: Value itself for the first, the
   --  value of its first component for the second, and so on. None when
   --  Value is not written so.
   function Aggregate_Of_Dimension
     (Value     : Libadalang.Analysis.Expr'Class;
      Dimension : Positive) return Libadalang.Analysis.Expr
   is
      Current : Libadalang.Analysis.Expr := Value.As_Expr;
   begin
      for Level in 1 .. Dimension loop
         while not Libadalang.Analysis.Is_Null (Current)
           and then Current.Kind = Libadalang.Common.Ada_Paren_Expr
         loop
            Current := Current.As_Paren_Expr.F_Expr;
         end loop;

         if Libadalang.Analysis.Is_Null (Current)
           or else Current.Kind not in Libadalang.Common.Ada_Base_Aggregate
         then
            return Libadalang.Analysis.No_Expr;
         elsif Level < Dimension then
            if Current.As_Base_Aggregate.F_Assocs.Children_Count = 0
              or else Current.As_Base_Aggregate.F_Assocs.Child (1).Kind /=
                Libadalang.Common.Ada_Aggregate_Assoc
            then
               return Libadalang.Analysis.No_Expr;
            end if;
            Current :=
              Current.As_Base_Aggregate.F_Assocs.Child (1)
                .As_Aggregate_Assoc.F_R_Expr;
         end if;
      end loop;
      return Current;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Aggregate_Of_Dimension;

   --  True when Value is an array aggregate with an others choice: it has
   --  the bounds of what it is given to, whatever they are.
   function Takes_Target_Bounds
     (Value : Libadalang.Analysis.Expr'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Value) then
         return False;
      elsif Value.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Takes_Target_Bounds (Value.As_Paren_Expr.F_Expr);
      elsif Value.Kind not in Libadalang.Common.Ada_Base_Aggregate then
         return False;
      end if;

      for Assoc of Value.As_Base_Aggregate.F_Assocs loop
         if Assoc.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            for Choice of Assoc.As_Aggregate_Assoc.F_Designators loop
               if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
                  return True;
               end if;
            end loop;
         end if;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Takes_Target_Bounds;

   --  The values a choice of an array aggregate stands for, when it is a
   --  static value or a range between two.
   function Static_Choice
     (Choice : Libadalang.Analysis.Ada_Node'Class) return Abstract_Range
   is
      Low, High : Abstract_Int;
   begin
      if Choice.Kind not in Libadalang.Common.Ada_Expr then
         return Unknown_Range;
      elsif Choice.Kind = Libadalang.Common.Ada_Bin_Op
        and then Choice.As_Bin_Op.F_Op.Kind =
          Libadalang.Common.Ada_Op_Double_Dot
      then
         Low := Static_Integer (Choice.As_Bin_Op.F_Left);
         High := Static_Integer (Choice.As_Bin_Op.F_Right);
      else
         Low := Static_Integer (Choice.As_Expr);
         High := Low;
      end if;
      return
        (Has_Low => Low.Known, Low => Low.Value,
         Has_High => High.Known, High => High.Value);
   exception
      when others =>
         return Unknown_Range;
   end Static_Choice;

   --  True when the subtype of the array Item is its own: that of the
   --  object or component it names, of the function it calls or of the
   --  subtype it is converted to or qualified with. An aggregate, a string
   --  literal or a conditional expression has the type its context
   --  expects, which says nothing of its length, and a slice the type of
   --  its prefix.
   function Has_Own_Subtype
     (Item : Libadalang.Analysis.Expr'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Item) then
         return False;
      elsif Item.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Has_Own_Subtype (Item.As_Paren_Expr.F_Expr);
      elsif Item.Kind in Libadalang.Common.Ada_Bin_Op_Range
                       | Libadalang.Common.Ada_Un_Op
      then
         return Origin_Of_Operator (Item) = Declared;
      end if;
      --  A slice has the type of what it is a slice of, and the bounds
      --  of its range.
      return Item.Kind in Libadalang.Common.Ada_Identifier
        | Libadalang.Common.Ada_Dotted_Name
        | Libadalang.Common.Ada_Qual_Expr
        | Libadalang.Common.Ada_Explicit_Deref
        or else
          (Item.Kind = Libadalang.Common.Ada_Call_Expr
           and then Item.As_Call_Expr.P_Kind /=
             Libadalang.Common.Array_Slice);
   exception
      when others =>
         return False;
   end Has_Own_Subtype;

   --  True when Left and Right are one and the same constrained array
   --  subtype: what is of it has its bounds, whatever they are.
   function Same_Constrained_Subtype
     (Left, Right : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is
   begin
      return not Libadalang.Analysis.Is_Null (Left)
        and then not Libadalang.Analysis.Is_Null (Right)
        and then Libadalang.Analysis."="
                   (Libadalang.Analysis.Ada_Node (Left),
                    Libadalang.Analysis.Ada_Node (Right))
        and then Array_Dimensions (Left) > 0
        and then Left.P_Is_Definite_Subtype (Left);
   exception
      when others =>
         return False;
   end Same_Constrained_Subtype;

   --  The length of the Dimension-th dimension of the array Item denotes,
   --  when its form and the declarations it names give it with static
   --  values, as a compiler knows it: an object, a component or the result
   --  of a call or a conversion whose subtype fixes its bounds, a slice
   --  between two static bounds, a string literal, a positional aggregate.
   function Static_Array_Length
     (Item      : Libadalang.Analysis.Expr'Class;
      Dimension : Positive) return Abstract_Int
   is
   begin
      if Libadalang.Analysis.Is_Null (Item) then
         return Unknown_Int;
      end if;

      case Item.Kind is
         when Libadalang.Common.Ada_Paren_Expr =>
            return Static_Array_Length
              (Item.As_Paren_Expr.F_Expr, Dimension);

         when Libadalang.Common.Ada_String_Literal =>
            return
              (if Dimension = 1
               then Known_Int
                 (Long_Long_Integer
                    (Item.As_String_Literal.P_Denoted_Value'Length))
               else Unknown_Int);

         when Libadalang.Common.Ada_Base_Aggregate =>
            declare
               Level : constant Libadalang.Analysis.Expr :=
                 Aggregate_Of_Dimension (Item, Dimension);
               Count : Long_Long_Integer := 0;
            begin
               if Libadalang.Analysis.Is_Null (Level)
                 or else not Libadalang.Analysis.Is_Null
                               (Level.As_Base_Aggregate.F_Ancestor_Expr)
               then
                  return Unknown_Int;
               end if;
               for Assoc of Level.As_Base_Aggregate.F_Assocs loop
                  if Assoc.Kind /= Libadalang.Common.Ada_Aggregate_Assoc then
                     return Unknown_Int;
                  elsif Assoc.As_Aggregate_Assoc.F_Designators
                    .Children_Count = 0
                  then
                     Count := Count + 1;
                  else
                     --  Named: each choice a static value or a range
                     --  between two, which a legal aggregate has without
                     --  gap or overlap.
                     for Choice of Assoc.As_Aggregate_Assoc.F_Designators
                     loop
                        declare
                           Chosen : constant Abstract_Range :=
                             Static_Choice (Choice);
                        begin
                           if not Chosen.Has_Low or else not Chosen.Has_High
                             or else Chosen.Low > Chosen.High
                           then
                              return Unknown_Int;
                           end if;
                           Count := Count + (Chosen.High - Chosen.Low) + 1;
                        end;
                     end loop;
                  end if;
               end loop;
               return Known_Int (Count);
            end;

         when Libadalang.Common.Ada_Identifier
            | Libadalang.Common.Ada_Dotted_Name =>
            --  What the declaration of the object, the formal or the
            --  component says, when it gives a constrained subtype: one
            --  declared with an unconstrained subtype has the bounds of
            --  its initial value, which are not static whatever that is.
            declare
               Decl      : constant Libadalang.Analysis.Basic_Decl :=
                 Item.As_Name.P_Referenced_Decl;
               Type_Expr : Libadalang.Analysis.Type_Expr :=
                 Libadalang.Analysis.No_Type_Expr;
            begin
               if Libadalang.Analysis.Is_Null (Decl) then
                  return Unknown_Int;
               elsif Decl.Kind = Libadalang.Common.Ada_Component_Decl then
                  Type_Expr :=
                    Decl.As_Component_Decl.F_Component_Def.F_Type_Expr;
               elsif Decl.Kind = Libadalang.Common.Ada_Param_Spec then
                  Type_Expr := Decl.As_Param_Spec.F_Type_Expr;
               elsif Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
               then
                  if not Libadalang.Analysis.Is_Null
                           (Decl.As_Object_Decl.F_Renaming_Clause)
                  then
                     return Static_Array_Length
                       (Decl.As_Object_Decl.F_Renaming_Clause
                          .F_Renamed_Object,
                        Dimension);
                  end if;
                  Type_Expr := Decl.As_Object_Decl.F_Type_Expr;
               end if;

               if Is_Constrained_Array
                    (Designated_Type (Type_Expr), Type_Expr)
               then
                  return Declared_Array_Length
                    (Designated_Type (Type_Expr), Type_Expr, Dimension);
               end if;
               return Unknown_Int;
            end;

         when Libadalang.Common.Ada_If_Expr =>
            --  A conditional expression: each of its dependent
            --  expressions is given to the target, and it has a static
            --  length when they all have the same.
            declare
               Chosen : constant Libadalang.Analysis.If_Expr :=
                 Item.As_If_Expr;
               Length : constant Abstract_Int :=
                 Static_Array_Length (Chosen.F_Then_Expr, Dimension);
            begin
               if not Length.Known
                 or else Libadalang.Analysis.Is_Null (Chosen.F_Else_Expr)
                 or else Static_Array_Length (Chosen.F_Else_Expr, Dimension)
                   /= Length
               then
                  return Unknown_Int;
               end if;
               for Part of Chosen.F_Alternatives loop
                  if Static_Array_Length
                       (Part.As_Elsif_Expr_Part.F_Then_Expr, Dimension) /=
                    Length
                  then
                     return Unknown_Int;
                  end if;
               end loop;
               return Length;
            end;

         when Libadalang.Common.Ada_Case_Expr =>
            declare
               Length : Abstract_Int := Unknown_Int;
               First  : Boolean := True;
            begin
               for Part of Item.As_Case_Expr.F_Cases loop
                  declare
                     Here : constant Abstract_Int :=
                       Static_Array_Length
                         (Part.As_Case_Expr_Alternative.F_Expr, Dimension);
                  begin
                     if not Here.Known
                       or else (not First and then Here /= Length)
                     then
                        return Unknown_Int;
                     end if;
                     Length := Here;
                     First := False;
                  end;
               end loop;
               return Length;
            end;

         when Libadalang.Common.Ada_Call_Expr =>
            if Item.As_Call_Expr.P_Kind = Libadalang.Common.Array_Slice then
               declare
                  Interval : constant Libadalang.Analysis.Ada_Node :=
                    Item.As_Call_Expr.F_Suffix.As_Ada_Node;
                  Low, High : Abstract_Int;
               begin
                  if Dimension /= 1 then
                     return Unknown_Int;
                  elsif Interval.Kind = Libadalang.Common.Ada_Attribute_Ref
                    and then Normalized_Text
                               (Interval.As_Attribute_Ref.F_Attribute) =
                      "range"
                    and then
                      (Libadalang.Analysis.Is_Null
                         (Interval.As_Attribute_Ref.F_Args)
                       or else Interval.As_Attribute_Ref.F_Args
                         .Children_Count = 0)
                  then
                     --  X (Y'Range): as long as Y, or as the subtype Y.
                     return Range_Length
                       (Fixed_Bounds (Interval.As_Attribute_Ref.F_Prefix, 1));
                  elsif Interval.Kind /= Libadalang.Common.Ada_Bin_Op
                    or else Interval.As_Bin_Op.F_Op.Kind /=
                      Libadalang.Common.Ada_Op_Double_Dot
                  then
                     --  X (Subtype_Name), most of all.
                     return Range_Length
                       (Discrete_Definition_Range
                          (Interval, Empty_Flow_State));
                  end if;
                  Low := Static_Integer (Interval.As_Bin_Op.F_Left);
                  High := Static_Integer (Interval.As_Bin_Op.F_Right);
                  if not Low.Known or else not High.Known then
                     return Unknown_Int;
                  end if;
                  return Range_Length
                    ((Has_Low => True, Low => Low.Value,
                      Has_High => True, High => High.Value));
               end;
            end if;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            --  The result of "and", "or" and "xor" on arrays has the
            --  bounds of the left operand, and the operation its own check
            --  that the right one has the same length.
            if Item.As_Bin_Op.F_Op.Kind in Libadalang.Common.Ada_Op_And
                 | Libadalang.Common.Ada_Op_Or
                 | Libadalang.Common.Ada_Op_Xor
              and then Origin_Of_Operator (Item) = Predefined
            then
               declare
                  Left : constant Abstract_Int :=
                    Static_Array_Length (Item.As_Bin_Op.F_Left, Dimension);
               begin
                  return
                    (if Left.Known then Left
                     else Static_Array_Length
                       (Item.As_Bin_Op.F_Right, Dimension));
               end;
            elsif Origin_Of_Operator (Item) /= Declared then
               --  A concatenation, most of all.
               return Unknown_Int;
            end if;

         when Libadalang.Common.Ada_Un_Op =>
            if Item.As_Un_Op.F_Op.Kind = Libadalang.Common.Ada_Op_Not
              and then Origin_Of_Operator (Item) = Predefined
            then
               return Static_Array_Length (Item.As_Un_Op.F_Expr, Dimension);
            elsif Origin_Of_Operator (Item) /= Declared then
               return Unknown_Int;
            end if;

         when others =>
            null;
      end case;

      --  A call, a conversion, a qualified expression, a dereference: what
      --  its subtype says.
      if Has_Own_Subtype (Item) then
         return Subtype_Array_Length (Item.P_Expression_Type, Dimension);
      end if;
      return Unknown_Int;
   exception
      when others =>
         return Unknown_Int;
   end Static_Array_Length;

   --  True when an Array_Index Call_Expr is indexing into an array *slice*
   --  (X (Lo .. Hi) (I)), not an array object. A slice's index bounds are
   --  its own Lo .. Hi -- which may be empty or a proper sub-range -- not
   --  the array type's declared index subtype, so proving I against the
   --  type's index bounds (what Array_Index_Range returns for the slice's
   --  P_Expression_Type) is unsound: it would call an out-of-slice index
   --  safe (see FP-064). The scalar domain does not model slice bounds, so
   --  such an index check is recorded conservatively as unproved rather
   --  than proved.
   function Indexed_Prefix_Is_Slice
     (Call : Libadalang.Analysis.Call_Expr) return Boolean is
   begin
      return
        Call.F_Name.Kind = Libadalang.Common.Ada_Call_Expr
        and then Call.F_Name.As_Call_Expr.P_Kind =
                   Libadalang.Common.Array_Slice;
   exception
      when others =>
         return False;
   end Indexed_Prefix_Is_Slice;

   --  Checked separately from Check_Conversion_Or_Index so Verify_Subprogram's
   --  Finalize_Node can replay the same determination against a CFG node's
   --  own fully-converged State, marked Final (see FP-035, following
   --  FP-031/FP-034's Ada_Identifier/Range_Check fixes).
   --  The array object and dimension an attribute reference ranges over.
   --  Object is the defining name of a declared object or parameter of an
   --  array type, the only prefixes whose bounds cannot change while the
   --  name is visible; Dimension is 0 for anything else.
   type Own_Range_Target is record
      Object    : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Dimension : Natural := 0;
   end record;

   No_Own_Range_Target : constant Own_Range_Target := (others => <>);

   --  The defining name Prefix denotes when Prefix is the plain name of an
   --  array object: a declared object (not a renaming) or a parameter. A
   --  component, a dereference, a slice or a call result is none of these:
   --  what those denote can be replaced while the same text still names it.
   function Array_Object_Key
     (Prefix : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Prefix)
        or else Prefix.Kind /= Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Prefix.As_Name.P_Referenced_Decl;
         Typ  : constant Libadalang.Analysis.Base_Type_Decl :=
           Prefix.As_Expr.P_Expression_Type;
      begin
         if Libadalang.Analysis.Is_Null (Decl)
           or else Libadalang.Analysis.Is_Null (Typ)
           or else not Typ.P_Is_Array_Type
           or else Typ.P_Is_Access_Type
         then
            return Libadalang.Analysis.No_Ada_Node;
         elsif Decl.Kind = Libadalang.Common.Ada_Param_Spec
           or else
             (Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
              and then Libadalang.Analysis.Is_Null
                (Decl.As_Object_Decl.F_Renaming_Clause))
         then
            return Libadalang.Analysis.Ada_Node
              (Prefix.As_Name.P_Referenced_Defining_Name);
         end if;
         return Libadalang.Analysis.No_Ada_Node;
      end;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Array_Object_Key;

   --  What "A'Range", "A'First" or "A'Last" refers to, with or without an
   --  explicit static dimension.
   function Range_Attribute_Target
     (Attr : Libadalang.Analysis.Attribute_Ref) return Own_Range_Target
   is
      Result : Own_Range_Target :=
        (Object => Array_Object_Key (Attr.F_Prefix), Dimension => 1);
   begin
      if Libadalang.Analysis.Is_Null (Result.Object) then
         return No_Own_Range_Target;
      end if;

      if not Libadalang.Analysis.Is_Null (Attr.F_Args)
        and then Attr.F_Args.Children_Count > 0
      then
         declare
            Dimension : constant Abstract_Int :=
              (if Attr.F_Args.Children_Count = 1
               then Integer_Value (Assoc_Expression (Attr.F_Args, 1))
               else Unknown_Int);
         begin
            if not Dimension.Known or else Dimension.Value not in 1 .. 255
            then
               return No_Own_Range_Target;
            end if;
            Result.Dimension := Natural (Dimension.Value);
         end;
      end if;
      return Result;
   exception
      when others =>
         return No_Own_Range_Target;
   end Range_Attribute_Target;

   --  True when Index_Value, the Dimension-th index of the indexed
   --  component Indexed, is the parameter of a "for ... in" loop that
   --  ranges over that same dimension of the very object being indexed:
   --  "for I in A'Range loop ... A (I)", or "A'First .. A'Last" spelled
   --  out. A loop parameter is a constant, and the bounds of a declared
   --  array object or array parameter are fixed for as long as its name is
   --  visible, so the index is within them on every iteration whatever
   --  those bounds are -- the one index check that needs no bound at all.
   function Index_Is_Own_Range_Loop_Parameter
     (Indexed     : Libadalang.Analysis.Call_Expr;
      Index_Value : Libadalang.Analysis.Expr'Class;
      Dimension   : Positive) return Boolean
   is
      function Attribute_Target
        (Node : Libadalang.Analysis.Ada_Node'Class;
         Name : String) return Own_Range_Target is
      begin
         if Libadalang.Analysis.Is_Null (Node)
           or else Node.Kind /= Libadalang.Common.Ada_Attribute_Ref
           or else Text_Utils.Normalize_Rule_Name
             (Ada_Text.Node_Text (Node.As_Attribute_Ref.F_Attribute)) /= Name
         then
            return No_Own_Range_Target;
         end if;
         return Range_Attribute_Target (Node.As_Attribute_Ref);
      end Attribute_Target;

      Object : constant Libadalang.Analysis.Ada_Node :=
        Array_Object_Key (Indexed.F_Name);
      Index  : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Index_Value);
      Target : Own_Range_Target := No_Own_Range_Target;
   begin
      if Libadalang.Analysis.Is_Null (Object) then
         return False;
      end if;

      while not Libadalang.Analysis.Is_Null (Index)
        and then Index.Kind = Libadalang.Common.Ada_Paren_Expr
      loop
         Index := Libadalang.Analysis.Ada_Node (Index.As_Paren_Expr.F_Expr);
      end loop;
      if Libadalang.Analysis.Is_Null (Index)
        or else Index.Kind /= Libadalang.Common.Ada_Identifier
      then
         return False;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Index.As_Name.P_Referenced_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Decl)
           or else Decl.Kind /= Libadalang.Common.Ada_For_Loop_Var_Decl
           or else Decl.Parent.Kind /= Libadalang.Common.Ada_For_Loop_Spec
           or else Decl.Parent.As_For_Loop_Spec.F_Loop_Type.Kind /=
             Libadalang.Common.Ada_Iter_Type_In
         then
            return False;
         end if;

         declare
            Iter_Expr : constant Libadalang.Analysis.Ada_Node :=
              Decl.Parent.As_For_Loop_Spec.F_Iter_Expr;
         begin
            if Iter_Expr.Kind = Libadalang.Common.Ada_Attribute_Ref then
               Target := Attribute_Target (Iter_Expr, "range");
            elsif Iter_Expr.Kind = Libadalang.Common.Ada_Bin_Op
              and then Iter_Expr.As_Bin_Op.F_Op =
                Libadalang.Common.Ada_Op_Double_Dot
            then
               Target :=
                 Attribute_Target (Iter_Expr.As_Bin_Op.F_Left, "first");
               if Target /=
                 Attribute_Target (Iter_Expr.As_Bin_Op.F_Right, "last")
               then
                  return False;
               end if;
            end if;
         end;
      end;

      return Target.Dimension = Dimension
        and then Libadalang.Analysis."=" (Target.Object, Object);
   exception
      when others =>
         return False;
   end Index_Is_Own_Range_Loop_Parameter;

   procedure Check_Index_Range
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Index_Value : Libadalang.Analysis.Expr'Class;
      Bounds      : Abstract_Range;
      State       : Flow_State;
      Symbols     : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final       : Boolean := False;
      Indexed     : Libadalang.Analysis.Call_Expr :=
        Libadalang.Analysis.No_Call_Expr;
      Dimension   : Positive := 1)
   is
   begin
      if Definitely_Outside_Range (Index_Value, Bounds, State) then
         Record_Definite_Error
           (Unit, Index_Value, Proof.Index_Check, Proof.Abstract_Interpretation,
            "index is outside the array index subtype",
            "index range is outside the array bounds", Final => Final);
         Report_Flow_Violation
           (Unit, Index_Value, Rules.Known_Index_Check_Failure,
            "index is outside the array index subtype",
            Explanation =>
              "Abstract interpretation found that every represented " &
              "index value is outside the array bounds.",
            Evidence => "index range is outside the array bounds");
      elsif Config.Verification_Mode then
         if not Libadalang.Analysis.Is_Null (Indexed)
           and then Index_Is_Own_Range_Loop_Parameter
             (Indexed, Index_Value, Dimension)
         then
            --  proof-path: index-own-range
            Record_Proved_Safe
              (Unit, Index_Value, Proof.Index_Check, Proof.Static_Evaluation,
               "index is the parameter of a loop over this array's own " &
                 "range",
               "loop parameter ranges over the indexed object's bounds",
               Final => Final);
         elsif Definitely_Inside_Range (Index_Value, Bounds, State) then
            --  proof-path: index-abstract
            Record_Proved_Safe
              (Unit, Index_Value, Proof.Index_Check,
               Proof.Abstract_Interpretation,
               "index range is contained in the array index bounds",
               "index bounds are within array bounds", Final => Final);
         else
            declare
               Outcome : constant VC.VC_Outcome :=
                 VC.Decide_Bounds (Index_Value, Bounds, State, Symbols);
            begin
               case Outcome.Result is
                  when VC.VC_Proved =>
                     --  proof-path: index-external
                     Record_Proved_Safe
                       (Unit, Index_Value, Proof.Index_Check,
                        Proof.External_Prover,
                        "scalar verification condition proves the index is " &
                          "inside the array bounds",
                        VC.Evidence, Final => Final);
                  when VC.VC_Refuted =>
                     Record_Definite_Error
                       (Unit, Index_Value, Proof.Index_Check,
                        Proof.External_Prover,
                        "index is outside the array index subtype",
                        VC.Evidence, Final => Final);
                     Report_Flow_Violation
                       (Unit, Index_Value,
                        Rules.Known_Index_Check_Failure,
                        "index is outside the array index subtype",
                        Explanation =>
                          "The scalar verification condition establishes " &
                          "that the index cannot satisfy the array bounds.",
                        Evidence => VC.Evidence);
                  when others =>
                     --  No declaration fixes the object's bounds, but the
                     --  index may still be provably within them: against
                     --  the object's own 'First and 'Last as symbols.
                     if (not Bounds.Has_Low or else not Bounds.Has_High)
                       and then not Libadalang.Analysis.Is_Null (Indexed)
                       and then VC.Decide_Index_In_Object
                         (Index_Value, Indexed.F_Name, State, Symbols,
                          Dimension)
                           .Result = VC.VC_Proved
                     then
                        --  proof-path: index-symbolic-bounds
                        Record_Proved_Safe
                          (Unit, Index_Value, Proof.Index_Check,
                           Proof.External_Prover,
                           "scalar verification condition proves the " &
                             "index is within the object's own bounds",
                           VC.Evidence, Final => Final);
                     else
                        Record_VC_Unproved
                          (Unit, Index_Value, Proof.Index_Check,
                           Proof.Abstract_Interpretation,
                           "index-check failure is not established, but " &
                             "absence is not proved",
                           "index and bound ranges remain inconclusive",
                           Outcome, Final => Final);
                     end if;
               end case;
            end;
         end if;
      else
         Record_Unproved
           (Unit, Index_Value, Proof.Index_Check, Proof.Abstract_Interpretation,
            "index-check failure is not established, but absence is not " &
              "proved",
            Imprecision => "index and bound ranges remain inconclusive",
            Final => Final);
      end if;
   end Check_Index_Range;

   procedure Check_Conversion_Or_Index
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Call  : Libadalang.Analysis.Call_Expr;
      State : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State)
   is
   begin
      case Call.P_Kind is
         when Libadalang.Common.Type_Conversion =>
            declare
               Decl  : constant Libadalang.Analysis.Basic_Decl :=
                 Call.F_Name.P_Referenced_Decl;
               Value : constant Libadalang.Analysis.Expr :=
                 Assoc_Expression (Call.F_Suffix, 1);
            begin
               if not Libadalang.Analysis.Is_Null (Decl)
                 and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
                 and then not Libadalang.Analysis.Is_Null (Value)
               then
                  Check_Value_Range
                    (Unit, Value, Decl.As_Base_Type_Decl, State,
                     Rules.Known_Range_Check_Failure,
                     "value is outside the target subtype range", Symbols);

                  if Config.Rule_States (Rules.Redundant_Type_Conversion) =
                       Config.Enabled
                  then
                     declare
                        Value_Type : constant
                          Libadalang.Analysis.Base_Type_Decl :=
                            Value.P_Expression_Type;
                     begin
                        if not Libadalang.Analysis.Is_Null (Value_Type)
                          and then Libadalang.Analysis.Ada_Node (Value_Type) =
                            Libadalang.Analysis.Ada_Node
                              (Decl.As_Base_Type_Decl)
                        then
                           Report_Flow_Violation
                             (Unit, Call, Rules.Redundant_Type_Conversion,
                              "conversion has no effect because the " &
                                "operand already has this type");
                        end if;
                     end;
                  end if;
               end if;
            end;

         when Libadalang.Common.Array_Index =>
            declare
               Array_Type : constant Libadalang.Analysis.Base_Type_Decl :=
                 Call.F_Name.P_Expression_Type;
            begin
               if not Libadalang.Analysis.Is_Null (Array_Type)
                 and then Array_Type.P_Is_Array_Type
               then
                  declare
                     Dimensions : constant Positive :=
                       (if Call.F_Suffix.Kind in Libadalang.Common.Ada_Expr
                        then 1 else Call.F_Suffix.Children_Count);
                  begin
                     for Dim in 1 .. Dimensions loop
                        declare
                           Index_Value : constant Libadalang.Analysis.Expr :=
                             Assoc_Expression (Call.F_Suffix, Dim);
                           Bounds : constant Abstract_Range :=
                             Array_Object_Index_Range
                               (Call.F_Name, Dim, State);
                        begin
                           if Config.Rule_States
                                (Rules.Known_Index_Check_Failure) =
                                  Config.Enabled
                             and then not Libadalang.Analysis.Is_Null
                               (Index_Value)
                           then
                              if Indexed_Prefix_Is_Slice (Call) then
                                 Record_Unproved
                                   (Unit, Index_Value, Proof.Index_Check,
                                    Proof.Abstract_Interpretation,
                                    "index-check failure is not established, " &
                                      "but absence is not proved",
                                    Imprecision =>
                                      "indexed prefix is an array slice; " &
                                      "slice bounds are not modelled by the " &
                                      "scalar domain");
                              else
                                 Check_Index_Range
                                   (Unit, Index_Value, Bounds, State, Symbols,
                                    Indexed => Call, Dimension => Dim);
                              end if;
                           end if;
                        end;
                     end loop;
                  end;
               end if;
            end;

         when others =>
            null;
      end case;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping conversion/index check: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Check_Conversion_Or_Index;

   --  Checked separately from Scan_Expression_For_Flow_Bugs so
   --  Verify_Subprogram's Finalize_Node can replay the same determination
   --  against a CFG node's own fully-converged State, marked Final (see
   --  FP-036, following FP-031/FP-034/FP-035's earlier fixes).
   procedure Check_Division_By_Zero
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Expr  : Libadalang.Analysis.Bin_Op;
      State : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final : Boolean := False)
   is
      Right       : constant Abstract_Int :=
        Integer_Value (Expr.F_Right, State);
      Right_Range : constant Abstract_Range :=
        Range_Value (Expr.F_Right, State);
   begin
      --  The division of a function a declaration defines is that
      --  function's business (FP-116).
      if Expr.F_Op not in Libadalang.Common.Ada_Op_Div
          | Libadalang.Common.Ada_Op_Mod
          | Libadalang.Common.Ada_Op_Rem
        or else Origin_Of_Operator (Expr) = Declared
      then
         return;
      end if;

      if Right.Known and then Right.Value = 0 then
         Record_Definite_Error
           (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
            Proof.Abstract_Interpretation,
            "right operand is zero in the incoming abstract state",
            "right operand => 0", Final => Final);
         if not Is_Static_Zero (Expr.F_Right) then
            Report_Flow_Violation
              (Unit, Expr.F_Right, Rules.Division_By_Zero,
               "right operand is zero here based on an earlier assignment",
               Explanation =>
                 "Flow analysis propagated the assigned value to this " &
                 "operation without an intervening write.",
               Evidence => "right operand => 0");
         end if;
      elsif Config.Verification_Mode then
         if (Right_Range.Has_High and then Right_Range.High < 0)
           or else (Right_Range.Has_Low and then Right_Range.Low > 0)
         then
            --  proof-path: division-abstract
            Record_Proved_Safe
              (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
               Proof.Abstract_Interpretation,
               "right operand range excludes zero",
               "right operand is strictly negative or positive",
               Final => Final);
         else
            declare
               Outcome : constant VC.VC_Outcome :=
                 VC.Decide_Nonzero (Expr.F_Right, State, Symbols);
            begin
               case Outcome.Result is
                  when VC.VC_Proved =>
                     --  proof-path: division-external
                     Record_Proved_Safe
                       (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
                        Proof.External_Prover,
                        "scalar verification condition proves the divisor " &
                          "is nonzero",
                        VC.Evidence, Final => Final);
                  when VC.VC_Refuted =>
                     Record_Definite_Error
                       (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
                        Proof.External_Prover,
                        "right operand is zero in every represented state",
                        VC.Evidence, Final => Final);
                     Report_Flow_Violation
                       (Unit, Expr.F_Right, Rules.Division_By_Zero,
                        "right operand is zero here",
                        Explanation =>
                          "The scalar verification condition establishes " &
                          "that the divisor is zero.",
                        Evidence => VC.Evidence);
                  when others =>
                     Record_VC_Unproved
                       (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
                        Proof.Abstract_Interpretation,
                        "zero has not been excluded from the divisor",
                        "the divisor range is unknown or contains zero",
                        Outcome, Final => Final);
               end case;
            end;
         end if;
      else
         Record_Unproved
           (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
            Proof.Abstract_Interpretation,
            "zero has not been excluded from the divisor",
            Imprecision => "the divisor range is unknown or contains zero",
            Final => Final);
      end if;
   end Check_Division_By_Zero;

   --  As Check_Division_By_Zero, for Integer_Overflow_Check.
   procedure Check_Integer_Overflow
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Bin_Op;
      State : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final : Boolean := False)
   is
   begin
      --  A call of a function a declaration defines has no overflow check
      --  of its own (FP-116).
      if Node.F_Op not in
        Libadalang.Common.Ada_Op_Plus
          | Libadalang.Common.Ada_Op_Minus
          | Libadalang.Common.Ada_Op_Mult
          | Libadalang.Common.Ada_Op_Div
          | Libadalang.Common.Ada_Op_Pow
        or else Origin_Of_Operator (Node) = Declared
      then
         return;
      end if;

      declare
         Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Node.As_Expr.P_Expression_Type;
      begin
         if not Libadalang.Analysis.Is_Null (Expr_Type)
           and then Expr_Type.P_Is_Int_Type
         then
            if Known_Arithmetic_Overflow (Node.As_Expr, State) then
               Record_Definite_Error
                 (Unit, Node, Proof.Integer_Overflow_Check,
                  Proof.Abstract_Interpretation,
                  "arithmetic result is outside its base type range",
                  "result range is outside the operation's base type",
                  Final => Final);
               Report_Flow_Violation
                 (Unit, Node, Rules.Known_Overflow_Failure,
                  "arithmetic result is outside its base type range",
                  Explanation =>
                    "Abstract interpretation found that every represented " &
                    "result is outside the operation's base type.",
                  Evidence =>
                    "result range is outside the operation's base type");
            elsif Config.Verification_Mode then
               if Arithmetic_Proved_Safe (Node.As_Expr, State) then
                  --  proof-path: overflow-abstract
                  Record_Proved_Safe
                    (Unit, Node, Proof.Integer_Overflow_Check,
                     Proof.Abstract_Interpretation,
                     "arithmetic result range is inside its base type",
                     "result bounds are within base-type bounds",
                     Final => Final);
               else
                  declare
                     Bounds : Abstract_Range :=
                       Overflow_Base_Range (Expr_Type, Node, State);
                     Name : constant String := Langkit_Support.Text.To_UTF8
                       (Expr_Type.P_Canonical_Fully_Qualified_Name);
                  begin
                     if not Bounds.Has_Low
                       and then not Bounds.Has_High
                       and then Name = "standard.integer"
                     then
                        Bounds := Type_Range (Expr_Type, State);
                     end if;

                     declare
                        Outcome : constant VC.VC_Outcome :=
                          VC.Decide_Bounds
                            (Node.As_Expr, Bounds, State, Symbols);
                     begin
                        case Outcome.Result is
                           when VC.VC_Proved =>
                              --  proof-path: overflow-external
                              Record_Proved_Safe
                                (Unit, Node, Proof.Integer_Overflow_Check,
                                 Proof.External_Prover,
                                 "scalar verification condition proves the " &
                                   "arithmetic result fits its base type",
                                 VC.Evidence, Final => Final);
                           when VC.VC_Refuted =>
                              Record_Definite_Error
                                (Unit, Node, Proof.Integer_Overflow_Check,
                                 Proof.External_Prover,
                                 "arithmetic result is outside its base " &
                                   "type range",
                                 VC.Evidence, Final => Final);
                              Report_Flow_Violation
                                (Unit, Node,
                                 Rules.Known_Overflow_Failure,
                                 "arithmetic result is outside its base " &
                                   "type range",
                                 Explanation =>
                                   "The scalar verification condition " &
                                   "establishes that the arithmetic result " &
                                   "cannot fit in its base type.",
                                 Evidence => VC.Evidence);
                           when others =>
                              Record_VC_Unproved
                                (Unit, Node,
                                 Proof.Integer_Overflow_Check,
                                 Proof.Abstract_Interpretation,
                                 "overflow is not established, but absence " &
                                   "is not proved",
                                 "the current range domain does not certify " &
                                   "the result",
                                 Outcome, Final => Final);
                        end case;
                     end;
                  end;
               end if;
            else
               Record_Unproved
                 (Unit, Node, Proof.Integer_Overflow_Check,
                  Proof.Abstract_Interpretation,
                  "overflow is not established, but absence is not proved",
                  Imprecision =>
                    "the current range domain does not certify the result",
                  Final => Final);
            end if;
         end if;
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Known_Overflow_Failure",
               Operation  => "evaluate arithmetic result bounds",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end;
   end Check_Integer_Overflow;

   --  An expression does not evaluate all of its operands. The right
   --  operand of a short-circuit form, a dependent expression of an if or
   --  case expression and the predicate of a quantified expression are
   --  evaluated only where what is evaluated before them lets evaluation get
   --  there. A check on such an operand is made in the state that leaves,
   --  and not at all when that state says the operand is never evaluated
   --  (FP-106): "Count > 0 and then Total / Count > 1" does not divide by
   --  zero where Count is known to be zero.

   --  True for X'Old and X'Loop_Entry. The prefix of the first is
   --  evaluated when the subprogram is entered and that of the second
   --  when the loop is. Where the attribute is written, an object the
   --  prefix names may hold another value, so the state there decides
   --  none of the checks inside the prefix (FP-112).
   function Evaluated_Earlier
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (Node.Kind = Libadalang.Common.Ada_Attribute_Ref
       and then Normalized_Text (Node.As_Attribute_Ref.F_Attribute) in
         "old" | "loop-entry");

   function Guards_Operands
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (Node.Kind in Libadalang.Common.Ada_If_Expr
         | Libadalang.Common.Ada_Elsif_Expr_Part
         | Libadalang.Common.Ada_Elsif_Expr_Part_List
         | Libadalang.Common.Ada_Case_Expr_Alternative
         | Libadalang.Common.Ada_Quantified_Expr
       or else
         (Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
          and then Node.As_Bin_Op.F_Op.Kind in
            Libadalang.Common.Ada_Op_And_Then
              | Libadalang.Common.Ada_Op_Or_Else));

   --  What is left of State and Symbols once Cond has evaluated to Truth.
   --  Dead when State says it never does. The effects of a function call
   --  in Cond are not applied here: the state of the node that contains the
   --  expression already has them (see Apply_Function_Call_Effects).
   procedure Apply_Guard
     (Cond    : Libadalang.Analysis.Expr'Class;
      Truth   : Boolean;
      State   : in out Flow_State;
      Symbols : in out VC.Symbolic_State;
      Dead    : in out Boolean)
   is
   begin
      if Dead or else Libadalang.Analysis.Is_Null (Cond) then
         return;
      end if;

      declare
         Value   : constant Abstract_Bool := Boolean_Value (Cond, State);
         Before  : constant Flow_State := State;
         True_State, False_State : Flow_State;
      begin
         if Value = (if Truth then Bool_False else Bool_True) then
            Dead := True;
            return;
         end if;

         Narrow_By_Condition (Cond, Before, True_State, False_State);
         State := (if Truth then True_State else False_State);
         Assume_Into (Symbols, Cond.As_Expr, Truth => Truth, Flow => Before);
      end;
   end Apply_Guard;

   --  True when a loop over Spec never runs its body in State: "in L .. H"
   --  where the least value L can have is above the greatest H can have.
   function Loop_Range_Is_Empty
     (Spec  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Spec)
        or else Spec.Kind /= Libadalang.Common.Ada_For_Loop_Spec
      then
         return False;
      end if;

      declare
         Loop_Spec : constant Libadalang.Analysis.For_Loop_Spec :=
           Spec.As_For_Loop_Spec;
         Domain    : constant Libadalang.Analysis.Ada_Node :=
           Loop_Spec.F_Iter_Expr;
      begin
         if Loop_Spec.F_Loop_Type.Kind /= Libadalang.Common.Ada_Iter_Type_In
           or else Domain.Kind /= Libadalang.Common.Ada_Bin_Op
           or else Domain.As_Bin_Op.F_Op.Kind /=
                     Libadalang.Common.Ada_Op_Double_Dot
         then
            return False;
         end if;

         declare
            Low  : constant Abstract_Range :=
              Range_Value (Domain.As_Bin_Op.F_Left, State);
            High : constant Abstract_Range :=
              Range_Value (Domain.As_Bin_Op.F_Right, State);
         begin
            return Low.Has_Low
              and then High.Has_High
              and then Low.Low > High.High;
         end;
      end;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("loop range not evaluated: " &
            Ada.Exceptions.Exception_Message (Exc));
         return False;
   end Loop_Range_Is_Empty;

   --  True when State bounds the selector of a case statement or expression
   --  and none of the values it may have selects the alternative with
   --  Choices: each choice is a known interval apart from them or, for
   --  "others", one choice of another alternative covers them all.
   --  Alternatives is the list the alternative is in.
   function Case_Alternative_Excluded
     (Selector     : Libadalang.Analysis.Expr'Class;
      Choices      : Libadalang.Analysis.Alternatives_List'Class;
      Alternatives : Libadalang.Analysis.Ada_Node'Class;
      State        : Flow_State) return Boolean
   is
      Bounds : constant Abstract_Range := Range_Value (Selector, State);

      function Choices_Of
        (Alternative : Libadalang.Analysis.Ada_Node)
         return Libadalang.Analysis.Alternatives_List
      is (if Alternative.Kind = Libadalang.Common.Ada_Case_Expr_Alternative
          then Alternative.As_Case_Expr_Alternative.F_Choices
          else Alternative.As_Case_Stmt_Alternative.F_Choices);

      function Covered_By_Another_Alternative return Boolean is
      begin
         for Index in 1 .. Alternatives.Children_Count loop
            for Choice of Choices_Of (Alternatives.Child (Index)) loop
               if Choice.Kind /= Libadalang.Common.Ada_Others_Designator then
                  declare
                     Interval : constant Static_Interval :=
                       Choice_Interval (Choice, State);
                  begin
                     if Interval.Known
                       and then Interval.Low <= Bounds.Low
                       and then Bounds.High <= Interval.High
                     then
                        return True;
                     end if;
                  end;
               end if;
            end loop;
         end loop;
         return False;
      end Covered_By_Another_Alternative;
   begin
      if not Bounds.Has_Low
        or else not Bounds.Has_High
        or else Bounds.Low > Bounds.High
      then
         return False;
      end if;

      for Choice of Choices loop
         if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
            return Covered_By_Another_Alternative;
         end if;

         declare
            Interval : constant Static_Interval :=
              Choice_Interval (Choice, State);
         begin
            if not Interval.Known
              or else (Interval.Low <= Bounds.High
                       and then Bounds.Low <= Interval.High)
            then
               return False;
            end if;
         end;
      end loop;
      return True;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("case alternative not evaluated: " &
            Ada.Exceptions.Exception_Message (Exc));
         return False;
   end Case_Alternative_Excluded;

   --  Gives State the parameter of Spec, the specification of a "for"
   --  loop or of a quantified expression, as it is where the body or the
   --  predicate is evaluated: holding a value, between the least its low
   --  bound can be in State and the greatest its high bound can. Nothing
   --  for "for E of A", whose parameter names a component.
   procedure Enter_Loop_Parameter
     (Spec  : Libadalang.Analysis.For_Loop_Spec;
      State : in out Flow_State);

   --  Narrows State and Symbols to those in which Child, a child of Parent,
   --  is evaluated when Parent is evaluated in them. Dead when it is not.
   procedure Narrow_For_Operand
     (Parent  : Libadalang.Analysis.Ada_Node'Class;
      Child   : Libadalang.Analysis.Ada_Node'Class;
      State   : in out Flow_State;
      Symbols : in out VC.Symbolic_State;
      Dead    : in out Boolean)
   is
      Operand : constant Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Child);

      function Is_Operand
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is (not Libadalang.Analysis.Is_Null (Node)
          and then Libadalang.Analysis.Ada_Node (Node) = Operand);
   begin
      if Libadalang.Analysis.Is_Null (Child) then
         return;
      end if;

      case Parent.Kind is
         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Expr : constant Libadalang.Analysis.Bin_Op := Parent.As_Bin_Op;
            begin
               if Is_Operand (Expr.F_Right) then
                  if Expr.F_Op.Kind = Libadalang.Common.Ada_Op_And_Then then
                     Apply_Guard (Expr.F_Left, True, State, Symbols, Dead);
                  elsif Expr.F_Op.Kind = Libadalang.Common.Ada_Op_Or_Else
                  then
                     Apply_Guard (Expr.F_Left, False, State, Symbols, Dead);
                  end if;
               end if;
            end;

         when Libadalang.Common.Ada_If_Expr =>
            declare
               Expr : constant Libadalang.Analysis.If_Expr :=
                 Parent.As_If_Expr;
            begin
               if Is_Operand (Expr.F_Then_Expr) then
                  Apply_Guard (Expr.F_Cond_Expr, True, State, Symbols, Dead);
               elsif Is_Operand (Expr.F_Alternatives) then
                  Apply_Guard (Expr.F_Cond_Expr, False, State, Symbols, Dead);
               elsif Is_Operand (Expr.F_Else_Expr) then
                  Apply_Guard (Expr.F_Cond_Expr, False, State, Symbols, Dead);
                  for Part of Expr.F_Alternatives loop
                     Apply_Guard
                       (Part.As_Elsif_Expr_Part.F_Cond_Expr, False, State,
                        Symbols, Dead);
                  end loop;
               end if;
            end;

         when Libadalang.Common.Ada_Elsif_Expr_Part_List =>
            --  An elsif part is reached when every part before it has
            --  declined.
            for Index in 1 .. Parent.Children_Count loop
               exit when Is_Operand (Parent.Child (Index));
               Apply_Guard
                 (Parent.Child (Index).As_Elsif_Expr_Part.F_Cond_Expr, False,
                  State, Symbols, Dead);
            end loop;

         when Libadalang.Common.Ada_Elsif_Expr_Part =>
            if Is_Operand (Parent.As_Elsif_Expr_Part.F_Then_Expr) then
               Apply_Guard
                 (Parent.As_Elsif_Expr_Part.F_Cond_Expr, True, State,
                  Symbols, Dead);
            end if;

         when Libadalang.Common.Ada_Case_Expr_Alternative =>
            if Is_Operand (Parent.As_Case_Expr_Alternative.F_Expr)
              and then Case_Alternative_Excluded
                         (Parent.Parent.Parent.As_Case_Expr.F_Expr,
                          Parent.As_Case_Expr_Alternative.F_Choices,
                          Parent.Parent, State)
            then
               Dead := True;
            end if;

         when Libadalang.Common.Ada_Quantified_Expr =>
            if Is_Operand (Parent.As_Quantified_Expr.F_Expr) then
               if Loop_Range_Is_Empty
                    (Parent.As_Quantified_Expr.F_Loop_Spec, State)
               then
                  Dead := True;
               else
                  Enter_Loop_Parameter
                    (Parent.As_Quantified_Expr.F_Loop_Spec, State);
               end if;
            end if;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("operand guard not applied: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Narrow_For_Operand;

   --  Reports Division_By_Zero for every "/", "mod", or "rem" under Node
   --  whose right operand is only known to be zero once State's earlier
   --  assignments are taken into account (a plain literal zero is already
   --  caught by the node-local checks, so this only adds cases those
   --  would miss).
   procedure Scan_Expression_For_Flow_Bugs
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      elsif Evaluated_Earlier (Node) then
         --  Only what holds in any state is looked for in the prefix:
         --  State is not the one it is evaluated in.
         Scan_Expression_For_Flow_Bugs
           (Unit, Node.As_Attribute_Ref.F_Prefix, Empty_Flow_State);
         return;
      end if;

      if Config.Verification_Mode
        and then Node.Kind = Libadalang.Common.Ada_Identifier
        and then Initialization_Read_Required (Node)
      then
         declare
            Key     : constant Libadalang.Analysis.Ada_Node :=
              Flow_Referenced_Name (Node);
            Current : Libadalang.Analysis.Ada_Node := Key;
            Tracked : Boolean := False;
         begin
            while not Libadalang.Analysis.Is_Null (Current) loop
               if Current.Kind in Libadalang.Common.Ada_Object_Decl_Range
                 or else Current.Kind in
                   Libadalang.Common.Ada_Param_Spec_Range
               then
                  Tracked := True;
                  exit;
               elsif Current.Kind in Libadalang.Common.Ada_Basic_Decl then
                  exit;
               end if;
               Current := Current.Parent;
            end loop;

            if Tracked then
               declare
                  Standing : Boolean;
               begin
                  Record_Standing_Value
                    (Unit, Node, Key, State, False, Standing);
                  if not Standing then
                     case Flow_Initialization (State, Key) is
                        when Bool_True =>
                           --  proof-path: initialization-live
                           Record_Proved_Safe
                             (Unit, Node, Proof.Initialization_Check,
                              Proof.Flow_Analysis,
                              "object is initialized on every incoming path",
                              "initialization => true");
                        when Bool_False =>
                           Record_Definite_Error
                             (Unit, Node, Proof.Initialization_Check,
                              Proof.Flow_Analysis,
                              "object is uninitialized on every incoming " &
                                "path",
                              "initialization => false");
                        when Bool_Unknown =>
                           Record_Unproved
                             (Unit, Node, Proof.Initialization_Check,
                              Proof.Flow_Analysis,
                              "object initialization is not established",
                              Imprecision =>
                                "incoming paths disagree or object is " &
                                  "external");
                     end case;
                  end if;
               end;
               Proof.Set_Subject
                 (Unit, Node, Proof.Initialization_Check, Key);
            end if;
         exception
            when E : others =>
               Report_Recoverable_Failure_Once
                 (Rule       => "Initialization_Check",
                  Operation  => "classify identifier initialization",
                  Source     => Ada_Text.Safe_Filename (Unit),
                  Occurrence => E);
         end;
      end if;

      if Config.Rule_States (Rules.Division_By_Zero) = Config.Enabled
        and then Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
      then
         Check_Division_By_Zero
           (Unit, Node.As_Bin_Op, State, Symbols);
      end if;

      if Config.Rule_States (Rules.Known_Overflow_Failure) = Config.Enabled
        and then Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
      then
         Check_Integer_Overflow
           (Unit, Node.As_Bin_Op, State, Symbols);
      end if;

      if Node.Kind = Libadalang.Common.Ada_Call_Expr then
         declare
            Call : constant Libadalang.Analysis.Call_Expr :=
              Node.As_Call_Expr;
         begin
            Check_Conversion_Or_Index (Unit, Call, State, Symbols);
            Check_Call_Precondition
              (Unit, Call.F_Name, State, Symbols);

            --  An out-only actual is a destination, not a read. Walking the
            --  raw call subtree would classify an uninitialized outer out
            --  parameter as read when it is forwarded directly to another
            --  out parameter. Use the resolved formal/actual mapping for
            --  ordinary calls; in-out and input actuals still get scanned.
            if Call.P_Kind = Libadalang.Common.Call then
               begin
                  Scan_Expression_For_Flow_Bugs
                    (Unit, Call.F_Name, State, Symbols);
                  for Pair of Call.F_Name.P_Call_Params loop
                     if Formal_Mode (Libadalang.Analysis.Param (Pair)) /=
                       Libadalang.Common.Ada_Mode_Out
                       or else Libadalang.Analysis.Actual (Pair).Kind /=
                         Libadalang.Common.Ada_Identifier
                     then
                        Scan_Expression_For_Flow_Bugs
                          (Unit, Libadalang.Analysis.Actual (Pair), State,
                           Symbols);
                     end if;
                  end loop;
                  return;
               exception
                  when others =>
                     --  If semantic parameter resolution is unavailable,
                     --  retain the conservative raw-tree scan below.
                     null;
               end;
            end if;
         end;
      end if;

      if Guards_Operands (Node) then
         for I in 1 .. Node.Children_Count loop
            declare
               Operand_State   : Flow_State := State;
               Operand_Symbols : VC.Symbolic_State := Symbols;
               Dead            : Boolean := False;
            begin
               Narrow_For_Operand
                 (Node, Node.Child (I), Operand_State, Operand_Symbols, Dead);
               if not Dead then
                  Scan_Expression_For_Flow_Bugs
                    (Unit, Node.Child (I), Operand_State, Operand_Symbols);
               end if;
            end;
         end loop;
      else
         for I in 1 .. Node.Children_Count loop
            Scan_Expression_For_Flow_Bugs
              (Unit, Node.Child (I), State, Symbols);
         end loop;
      end if;
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
            Report_Flow_Violation
              (Unit, Cond, Rules.Constant_Condition,
               "condition is always " & Bool_Name (Flow_Value) &
                 " based on an earlier assignment");
         end if;
      end;
   end Check_Flow_Condition;

   --  The condition carried by a proof-related pragma. Check uses its
   --  second argument (the first is the check kind); assertion pragmas and
   --  Assume use their first argument.
   function Pragma_Condition
     (Pragma_Node : Libadalang.Analysis.Pragma_Node)
      return Libadalang.Analysis.Expr
   is
      Name  : constant String := Normalized_Text (Pragma_Node.F_Id);
      Index : Positive := 1;
   begin
      if Name = "check" then
         Index := 2;
      elsif Name /= "assert"
        and then Name /= "assert-and-cut"
        and then Name /= "loop-invariant"
        and then Name /= "assume"
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
   end Pragma_Condition;

   function Verification_Pragma_Condition
     (Pragma_Node : Libadalang.Analysis.Pragma_Node)
      return Libadalang.Analysis.Expr
   is
   begin
      if Normalized_Text (Pragma_Node.F_Id) /= "loop-variant" then
         return Pragma_Condition (Pragma_Node);
      elsif Pragma_Node.F_Args.Children_Count = 0 then
         return Libadalang.Analysis.No_Expr;
      else
         return
           Pragma_Node.F_Args.Child (1)
             .As_Pragma_Argument_Assoc.P_Assoc_Expr;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Verification_Pragma_Condition;

   function Contains_VC_Arithmetic
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
        and then Node.As_Bin_Op.F_Op in
          Libadalang.Common.Ada_Op_Plus
            | Libadalang.Common.Ada_Op_Minus
            | Libadalang.Common.Ada_Op_Mult
            | Libadalang.Common.Ada_Op_Div
      then
         --  "/" joins "+"/"-"/"*" here for the same reason: its SMT
         --  translation is unbounded-integer arithmetic, so a refutation
         --  could be an artifact of ignoring machine-width overflow (e.g.
         --  Integer'First / -1) rather than a genuine Ada assertion
         --  failure. "mod"/"rem" are deliberately excluded: their result
         --  magnitude never exceeds the (already provably nonzero, see
         --  Divisor_Provably_Nonzero in vc_prover.adb) divisor, so they
         --  carry no such overflow risk and a refutation on them alone is
         --  trustworthy.
         return True;
      elsif Node.Kind = Libadalang.Common.Ada_Un_Op
        and then Node.As_Un_Op.F_Op in
          Libadalang.Common.Ada_Op_Minus | Libadalang.Common.Ada_Op_Abs
      then
         return True;
      end if;

      for Index in 1 .. Node.Children_Count loop
         if Contains_VC_Arithmetic (Node.Child (Index)) then
            return True;
         end if;
      end loop;
      return False;
   end Contains_VC_Arithmetic;

   --  FP-065: a statically-false assertion (pragma Assert (False) and the
   --  like) is a Known_Assertion_Failure *definite* error only where the
   --  pragma is actually reached. Walking outward from the condition to the
   --  enclosing body, this returns False as soon as the pragma is found to
   --  sit on a control path the analyzer cannot establish is taken -- an
   --  if-branch whose guard State does not prove True, an elsif/else/case
   --  alternative, or a loop body. In that case "the assertion would fail
   --  if reached, but its reachability is not established" (unproved) is the
   --  honest verdict rather than a definite error: an earlier statement on
   --  the only path in may itself always raise, which the flow domain does
   --  not model (found on AdaCore SPARK testsuite unit
   --  W316-007__string_multidim, where GNAT raises Constraint_Error at the
   --  enclosing "if" line). Straight-line asserts, and asserts under an
   --  if-condition State proves True, still report a definite error --
   --  CFG-proved-unreachable ones are already handled earlier by
   --  Finalize_Assertion_Check's Record_Unreachable guard.
   function Assertion_Point_Reachable
     (Cond  : Libadalang.Analysis.Expr;
      State : Flow_State) return Boolean
   is
      Child  : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Cond);
      Parent : Libadalang.Analysis.Ada_Node;
   begin
      loop
         Parent := Child.Parent;
         exit when Libadalang.Analysis.Is_Null (Parent);
         exit when Parent.Kind in
           Libadalang.Common.Ada_Subp_Body
             | Libadalang.Common.Ada_Package_Body
             | Libadalang.Common.Ada_Task_Body
             | Libadalang.Common.Ada_Entry_Body
             | Libadalang.Common.Ada_Expr_Function;

         case Parent.Kind is
            when Libadalang.Common.Ada_If_Stmt =>
               --  Only the THEN path, and only when its guard is provably
               --  taken in this State, keeps a definite verdict alive.
               if Libadalang.Analysis.Ada_Node
                    (Parent.As_If_Stmt.F_Then_Stmts) /= Child
                 or else Boolean_Value
                           (Parent.As_If_Stmt.F_Cond_Expr, State) /= Bool_True
               then
                  return False;
               end if;

            when Libadalang.Common.Ada_Elsif_Stmt_Part
               | Libadalang.Common.Ada_Case_Stmt
               | Libadalang.Common.Ada_Case_Stmt_Alternative
               | Libadalang.Common.Ada_Base_Loop_Stmt =>
               return False;

            when others =>
               null;
         end case;

         Child := Parent;
      end loop;
      return True;
   exception
      when others =>
         return False;
   end Assertion_Point_Reachable;

   --  Checked separately from Interpret_Proof_Pragma so Verify_Subprogram's
   --  Finalize_Node can replay the same determination against a CFG node's
   --  own fully-converged State, marked Final (see FP-032, following
   --  FP-031/FP-034's Ada_Identifier/Range_Check fixes).
   procedure Check_Proof_Pragma_Assertion
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Cond    : Libadalang.Analysis.Expr;
      State   : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final   : Boolean := False)
   is
   begin
      if Config.Rule_States (Rules.Known_Assertion_Failure) /=
        Config.Enabled
      then
         return;
      end if;

      declare
         Value     : constant Abstract_Bool := Boolean_Value (Cond, State);
         VC_Outcome : constant VC.VC_Outcome :=
           (if Config.Verification_Mode and then Value = Bool_Unknown
            then VC.Decide (Cond, State, Symbols) else VC.Unknown_Outcome);
         VC_Result : constant VC.VC_Result := VC_Outcome.Result;
      begin
         if (Value = Bool_False
             or else
               (VC_Result = VC.VC_Refuted
                and then not Contains_VC_Arithmetic (Cond)))
           and then not Assertion_Point_Reachable (Cond, State)
         then
            --  FP-065: the condition is false, but the pragma sits on a
            --  branch whose reachability this analysis cannot establish, so
            --  a definite-error claim would over-state what is known.
            Record_Unproved
              (Unit, Cond, Proof.Assertion_Check,
               Proof.Abstract_Interpretation,
               "assertion condition is false, but the enclosing branch " &
                 "guard is not established, so this point's reachability " &
                 "is not proved",
               Imprecision =>
                 "reachability of a conditionally-guarded assertion whose " &
                 "guard could not be evaluated is not modelled",
               Final => Final);
         elsif Value = Bool_False
           or else
             (VC_Result = VC.VC_Refuted
              and then not Contains_VC_Arithmetic (Cond))
         then
            Record_Definite_Error
              (Unit, Cond, Proof.Assertion_Check,
               (if VC_Result = VC.VC_Refuted
                then Proof.External_Prover
                else Proof.Abstract_Interpretation),
               "assertion condition is false based on the incoming state",
               (if VC_Result = VC.VC_Refuted
                then VC.Evidence
                else "assertion condition => false"),
               Final => Final);
            if Boolean_Value (Cond) = Bool_Unknown then
               Report_Flow_Violation
                 (Unit, Cond, Rules.Known_Assertion_Failure,
                  "assertion condition is false here based on earlier " &
                    "state",
                  Explanation =>
                    "The incoming flow state makes the assertion " &
                    "condition False.",
                  Evidence =>
                    (if VC_Result = VC.VC_Refuted
                     then VC.Evidence
                     else "assertion condition => false"));
            end if;
         elsif Config.Verification_Mode
           and then
             (Value = Bool_True or else VC_Result = VC.VC_Proved)
         then
            --  proof-path: assertion-decision
            Record_Proved_Safe
              (Unit, Cond, Proof.Assertion_Check,
               (if VC_Result = VC.VC_Proved
                then Proof.External_Prover
                else Proof.Abstract_Interpretation),
               (if VC_Result = VC.VC_Proved
                then "scalar verification condition proved by the " &
                  "external prover portfolio"
                else "assertion condition is true in the incoming state"),
               (if VC_Result = VC.VC_Proved
                then VC.Evidence
                else "assertion condition => true"),
               Final => Final);
         else
            Record_VC_Unproved
              (Unit, Cond, Proof.Assertion_Check,
               Proof.Abstract_Interpretation,
               "assertion failure is not established, but the assertion " &
                 "is not proved",
               "abstract interpretation and the scalar VC portfolio did " &
                 "not certify it",
               VC_Outcome,
               Final => Final);
         end if;
      end;
   end Check_Proof_Pragma_Assertion;

   function Interpret_Proof_Pragma
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Pragma_Node : Libadalang.Analysis.Pragma_Node;
      State       : Flow_State;
      Symbols     : VC.Symbolic_State := VC.Empty_Symbolic_State)
      return Flow_State
   is
      Name   : constant String := Normalized_Text (Pragma_Node.F_Id);
      Cond   : constant Libadalang.Analysis.Expr :=
        Pragma_Condition (Pragma_Node);
      Result : Flow_State := State;
   begin
      if Libadalang.Analysis.Is_Null (Cond) then
         return Result;
      end if;

      Scan_Expression_For_Flow_Bugs (Unit, Cond, State, Symbols);

      if Name /= "assume" then
         Check_Proof_Pragma_Assertion (Unit, Cond, State, Symbols);
      end if;

      --  Execution continues only when an assertion succeeds. Assume has
      --  the same state-narrowing effect without generating an obligation.
      declare
         True_State, False_State : Flow_State;
      begin
         Narrow_By_Condition (Cond, State, True_State, False_State);
         Result := True_State;
      end;
      return Result;
   end Interpret_Proof_Pragma;

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
                     Check_Value_Range
                       (Unit, Default,
                        Decl.F_Type_Expr.P_Designated_Type_Decl,
                        State, Rules.Known_Range_Check_Failure,
                        "initial value is outside the object's subtype range",
                        Constraint =>
                          Declared_Constraint (Decl.F_Type_Expr, State));

                     declare
                        Value      : constant Abstract_Int :=
                          Integer_Value (Default, State);
                        Bool_Value : constant Abstract_Bool :=
                          Boolean_Value (Default, State);
                     begin
                        --  A call in the initial value can write its out
                        --  and in out actuals and its global outputs
                        --  (FP-105).
                        Havoc_Effects_In (Default, State);
                        for Id of Decl.F_Ids loop
                           Flow_Set_Initialized
                             (State, Libadalang.Analysis.Ada_Node (Id),
                              Bool_True);
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
                  else
                     declare
                        Initialized : constant Abstract_Bool :=
                          Implicit_Initialization (Decl, State);
                     begin
                        for Id of Decl.F_Ids loop
                           Flow_Set_Initialized
                             (State, Libadalang.Analysis.Ada_Node (Id),
                              Initialized);
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
      --  What a loop over "L .. H", the bounds of Bounds, gives its
      --  parameter: it is never below the least value L can have in State,
      --  nor above the greatest H can. A side State says nothing of is the
      --  one a declaration would take from it ("T'Last", a constant).
      function Between
        (Bounds : Libadalang.Analysis.Bin_Op) return Abstract_Range
      is
         Low        : constant Abstract_Int :=
           Integer_Value (Bounds.F_Left, State);
         High       : constant Abstract_Int :=
           Integer_Value (Bounds.F_Right, State);
         Low_Range  : constant Abstract_Range :=
           Range_Value (Bounds.F_Left, State);
         High_Range : constant Abstract_Range :=
           Range_Value (Bounds.F_Right, State);
         Declared   : constant Abstract_Range :=
           Discrete_Definition_Range (Bounds, State);
         Result     : Abstract_Range;
      begin
         if Low.Known then
            Result.Has_Low := True;
            Result.Low := Low.Value;
         elsif Low_Range.Has_Low then
            Result.Has_Low := True;
            Result.Low := Low_Range.Low;
         elsif Declared.Has_Low then
            Result.Has_Low := True;
            Result.Low := Declared.Low;
         end if;

         if High.Known then
            Result.Has_High := True;
            Result.High := High.Value;
         elsif High_Range.Has_High then
            Result.Has_High := True;
            Result.High := High_Range.High;
         elsif Declared.Has_High then
            Result.Has_High := True;
            Result.High := Declared.High;
         end if;

         return Result;
      end Between;

      --  Inner, the range "L .. H" gives, within that of the subtype Mark
      --  names: a range that is not null has both its bounds in the
      --  subtype it constrains, or its elaboration raises Constraint_Error.
      function Within_Subtype
        (Inner : Abstract_Range;
         Mark  : Libadalang.Analysis.Name) return Abstract_Range
      is
         Outer  : constant Abstract_Range :=
           Discrete_Definition_Range (Mark, State);
         Result : Abstract_Range := Inner;
      begin
         if Outer.Has_Low
           and then (not Inner.Has_Low or else Inner.Low < Outer.Low)
         then
            Result.Has_Low := True;
            Result.Low := Outer.Low;
         end if;
         if Outer.Has_High
           and then (not Inner.Has_High or else Inner.High > Outer.High)
         then
            Result.Has_High := True;
            Result.High := Outer.High;
         end if;
         return Result;
      end Within_Subtype;

      function Is_Bounds
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is (Node.Kind = Libadalang.Common.Ada_Bin_Op
          and then Node.As_Bin_Op.F_Op = Libadalang.Common.Ada_Op_Double_Dot);
   begin
      if Libadalang.Analysis.Is_Null (Iter_Expr) then
         return Unknown_Range;
      end if;

      --  "for I in A'Range" over an array object whose bounds a
      --  declaration fixes; any other form that names a subtype ("for I in
      --  Index", "for I in Index'Range") is a discrete subtype definition.
      if Iter_Expr.Kind = Libadalang.Common.Ada_Attribute_Ref then
         declare
            Target : constant Own_Range_Target :=
              Range_Attribute_Target (Iter_Expr.As_Attribute_Ref);
         begin
            if Target.Dimension > 0 then
               return Array_Object_Index_Range
                 (Iter_Expr.As_Attribute_Ref.F_Prefix, Target.Dimension,
                  State);
            end if;
         end;
         return Discrete_Definition_Range (Iter_Expr, State);
      elsif Is_Bounds (Iter_Expr) then
         return Between (Iter_Expr.As_Bin_Op);
      elsif Iter_Expr.Kind in Libadalang.Common.Ada_Subtype_Indication_Range
        and then not Libadalang.Analysis.Is_Null
                       (Iter_Expr.As_Subtype_Indication.F_Constraint)
        and then Iter_Expr.As_Subtype_Indication.F_Constraint.Kind =
          Libadalang.Common.Ada_Range_Constraint
      then
         --  "for I in Index range L .. H".
         declare
            Indication : constant Libadalang.Analysis.Subtype_Indication :=
              Iter_Expr.As_Subtype_Indication;
            Bounds     : constant Libadalang.Analysis.Expr :=
              Indication.F_Constraint.As_Range_Constraint.F_Range.F_Range;
         begin
            if Is_Bounds (Bounds) then
               return Within_Subtype
                 (Between (Bounds.As_Bin_Op), Indication.F_Name);
            end if;
         end;
      end if;
      return Discrete_Definition_Range (Iter_Expr, State);
   end For_Loop_Range;

   procedure Enter_Loop_Parameter
     (Spec  : Libadalang.Analysis.For_Loop_Spec;
      State : in out Flow_State)
   is
      Key : constant Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Spec.F_Var_Decl.F_Id);
   begin
      if Spec.F_Loop_Type.Kind = Libadalang.Common.Ada_Iter_Type_In then
         Flow_Range_Set (State, Key, For_Loop_Range (Spec.F_Iter_Expr, State));
         Flow_Set_Initialized (State, Key, Bool_True);
      end if;
   end Enter_Loop_Parameter;

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
      --  A for loop over a range known to be empty runs nothing (FP-106).
      if Stmt.Kind = Libadalang.Common.Ada_For_Loop_Stmt
        and then Loop_Range_Is_Empty (Stmt.As_For_Loop_Stmt.F_Spec, State)
      then
         return (State => State, Terminated => False);
      end if;

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

   --  Whether Selector (already confirmed Known) is covered by one of Alt's
   --  choices: Match when it provably is, No_Match when every choice
   --  resolved and none covers it, and Unknown when some choice couldn't be
   --  resolved (e.g. a named constant outside this pass's tracked state)
   --  and therefore might cover it. "when others" always matches, since
   --  Ada requires it to be the final, exclusive alternative.
   type Case_Match_Result is (Match, No_Match, Unknown_Match);

   function Case_Alternative_Match_Result
     (Alt      : Libadalang.Analysis.Case_Stmt_Alternative;
      Selector : Abstract_Int;
      State    : Flow_State) return Case_Match_Result
   is
      Saw_Unresolved_Choice : Boolean := False;
   begin
      for Choice of Alt.F_Choices loop
         if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
            return Match;
         end if;

         declare
            Range_Value : constant Static_Interval :=
              Choice_Interval (Choice, State);
         begin
            if Range_Value.Known then
               if Selector.Value >= Range_Value.Low
                 and then Selector.Value <= Range_Value.High
               then
                  return Match;
               end if;
            else
               Saw_Unresolved_Choice := True;
            end if;
         end;
      end loop;

      if Saw_Unresolved_Choice then
         return Unknown_Match;
      else
         return No_Match;
      end if;
   end Case_Alternative_Match_Result;

   --  Interprets a case statement. When the selector's value is known from
   --  State, and every alternative up to and including the one that
   --  provably matches has fully resolvable choices, only that one
   --  alternative is interpreted (mirroring how Interpret_If picks a single
   --  branch). An alternative whose choices this pass can't fully resolve
   --  might itself be the true match, so encountering one before a proven
   --  match abandons the single-branch fast path entirely rather than risk
   --  skipping past the alternative that actually applies; the unresolved
   --  case then falls back, the same as an unknown selector, to
   --  interpreting every alternative from a copy of the entering State and
   --  joining the results, the same way an if statement's branches are
   --  joined.
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
               case Case_Alternative_Match_Result (Alt, Selector, State) is
                  when Match =>
                     return Interpret_Statements (Unit, Alt.F_Stmts, State);
                  when No_Match =>  --  adalang-analyzer: ignore Null_Case_Alternative -- rationale: keep scanning
                     null;  --  adalang-analyzer: ignore Null_Statement
                  when Unknown_Match =>
                     exit;
               end case;
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
               declare
                  Target : constant Target_Subtype :=
                    Stored_Subtype (Assign.F_Dest, State);
               begin
                  Check_Value_Range
                    (Unit, Assign.F_Expr, Target.Typ,
                     State, Rules.Known_Range_Check_Failure,
                     "assigned value is outside the target subtype range",
                     Constraint => Target.Constraint);
               end;
               Havoc_Effects_In (Assign.F_Dest, Next);
               Havoc_Effects_In (Assign.F_Expr, Next);

               declare
                  Target     : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Assigned_Name (Stmt);
                  Value      : constant Abstract_Int :=
                    Integer_Value (Assign.F_Expr, State);
                  Bool_Value : constant Abstract_Bool :=
                    Boolean_Value (Assign.F_Expr, State);
                  Bounds     : constant Abstract_Range :=
                    Range_Value (Assign.F_Expr, State);
               begin
                  Flow_Set (Next, Target, Value);
                  Flow_Bool_Set (Next, Target, Bool_Value);
                  Flow_Range_Set (Next, Target, Bounds);
                  Flow_Set_Initialized (Next, Target, Bool_True);
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

         when Libadalang.Common.Ada_Pragma_Node =>
            return
              (State => Interpret_Proof_Pragma
                 (Unit, Stmt.As_Pragma_Node, State),
               Terminated => False);

         when Libadalang.Common.Ada_Null_Stmt
            | Libadalang.Common.Ada_Label =>
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
      if Config.Verification_Mode
        or else
        (Config.Rule_States (Rules.Division_By_Zero) /= Config.Enabled
          and then Config.Rule_States (Rules.Constant_Condition) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Precondition_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Postcondition_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Assertion_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Range_Check_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Index_Check_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Overflow_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Redundant_Type_Conversion) /=
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
            then
               if Boolean_Value (Post, Result.State) = Bool_False then
                  Record_Definite_Error
                    (Unit, Post, Proof.Postcondition_Check,
                     Proof.Contract_Transfer,
                     "subprogram body makes the postcondition false",
                     "postcondition => false");
                  Report_Flow_Violation
                    (Unit, Post, Rules.Known_Postcondition_Failure,
                     "subprogram body makes the postcondition false",
                     Explanation =>
                       "The joined state at normal subprogram exits makes " &
                       "the postcondition False.",
                     Evidence => "postcondition => false");
               elsif Config.Verification_Mode
                 and then Boolean_Value (Post, Result.State) = Bool_True
               then
                  --  proof-path: postcondition-legacy
                  Record_Proved_Safe
                    (Unit, Post, Proof.Postcondition_Check,
                     Proof.Contract_Transfer,
                     "joined normal-exit state satisfies the postcondition",
                     "postcondition => true");
               else
                  Record_Unproved
                    (Unit, Post, Proof.Postcondition_Check,
                     Proof.Contract_Transfer,
                     "postcondition failure is not established, but the " &
                       "postcondition is not proved",
                     Imprecision =>
                       "joined exit state does not certify the contract");
               end if;
            end if;
         end if;
      end;
   end Interpret_Subprogram_Flow;

   procedure Verify_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Base_Subp_Body'Class)
   is
      package CFG renames Adalang_Analyzer.Control_Flow_Graph;
      use type CFG.Edge_Kind;
      use type CFG.Node_Kind;

      --  A subprogram body, or an expression function: its expression is
      --  the one statement of its graph.
      Graph : constant CFG.Graph :=
        (if Subprogram.Kind = Libadalang.Common.Ada_Expr_Function
         then CFG.Build (Subprogram.As_Expr_Function)
         else CFG.Build (Subprogram.As_Subp_Body));

      type State_Array is array (Positive range <>) of Flow_State;
      type Symbolic_State_Array is
        array (Positive range <>) of VC.Symbolic_State;
      type Boolean_Array is array (Positive range <>) of Boolean;
      type Natural_Array is array (Positive range <>) of Natural;

      type Loop_VC_Status is (Not_Seen, VC_Discharged, VC_Not_Discharged);

      type Loop_Invariant_Info is record
         Pragma_Node         : Libadalang.Analysis.Ada_Node :=
           Libadalang.Analysis.No_Ada_Node;
         Condition           : Libadalang.Analysis.Expr :=
           Libadalang.Analysis.No_Expr;
         Header              : CFG.Node_Id := CFG.No_Node;
         Leading             : Boolean := False;
         Initialization      : Loop_VC_Status := Not_Seen;
         Preservation        : Loop_VC_Status := Not_Seen;
         Initialization_By   : Proof.Analysis_Method :=
           Proof.Abstract_Interpretation;
         Preservation_By     : Proof.Analysis_Method :=
           Proof.Abstract_Interpretation;
         Initialization_Outcome : VC.VC_Outcome := VC.Unknown_Outcome;
         Preservation_Outcome   : VC.VC_Outcome := VC.Unknown_Outcome;
      end record;

      package Loop_Invariant_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Loop_Invariant_Info);

      type Loop_Variant_Info is record
         Pragma_Node : Libadalang.Analysis.Ada_Node :=
           Libadalang.Analysis.No_Ada_Node;
         Expression  : Libadalang.Analysis.Expr :=
           Libadalang.Analysis.No_Expr;
         Header      : CFG.Node_Id := CFG.No_Node;
         Leading     : Boolean := False;
         Direction   : VC.Loop_Variant_Direction := VC.Decreases;
         Direction_Supported : Boolean := False;
         Progress    : Loop_VC_Status := Not_Seen;
         Progress_By : Proof.Analysis_Method := Proof.External_Prover;
         Progress_Outcome : VC.VC_Outcome := VC.Unknown_Outcome;
      end record;

      package Loop_Variant_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Loop_Variant_Info);

      States : State_Array (1 .. CFG.Node_Count (Graph)) :=
        (others => Empty_Flow_State);
      Symbolic_States : Symbolic_State_Array (States'Range) :=
        (others => VC.Empty_Symbolic_State);
      Reachable : Boolean_Array (States'Range) := (others => False);
      Updates   : Natural_Array (States'Range) := (others => 0);

      --  How many CFG edges end at each node. A node only one edge leads to
      --  has exactly the state that edge carries, so a later visit replaces
      --  its state instead of joining the new one with the one before.
      In_Degree : Natural_Array (States'Range) := (others => 0);

      --  The function calls evaluated by each CFG node's own expression
      --  that may change state: a call to a function that is not known to
      --  be free of side effects, in a condition, an initializer, an
      --  assignment's right-hand side or a procedure call's actuals. Ada
      --  lets such a function write anything it can see, and fixes no
      --  order of evaluation within the expression, so the node's entry
      --  state must already omit whatever those calls may write (FP-093).
      package Call_Name_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Libadalang.Analysis.Name,
         "=" => Libadalang.Analysis."=");
      type Call_Name_Array is
        array (CFG.Node_Id range <>) of Call_Name_Vectors.Vector;
      Effectful_Calls : Call_Name_Array (States'Range);

      --  For every CFG node, whether it evaluates a call that is not taken
      --  to leave everything as it is (see Untrusted_Calls).
      Calls_Untrusted : Boolean_Array (States'Range) := (others => False);

      --  Set when the subprogram declares or assigns an object whose type
      --  may run user code implicitly: a controlled type's Initialize,
      --  Adjust and Finalize, or a component default that calls a function
      --  with side effects. That code runs at points no CFG node stands
      --  for (a scope exit, most of all), so facts about objects declared
      --  outside the subprogram are not kept at all (FP-094). When the type
      --  is itself declared inside the subprogram, its operations can see
      --  the subprogram's own objects too, and no value fact is kept.
      Implicit_Code_May_Run     : Boolean := False;
      Implicit_Code_Sees_Locals : Boolean := False;
      Loop_Invariants : Loop_Invariant_Vectors.Vector;
      Loop_Variants   : Loop_Variant_Vectors.Vector;
      Summary_Mode : Boolean := False;

      package Work_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => CFG.Node_Id);
      Work : Work_Vectors.Vector;
      Head : Positive := 1;

      --  True when Node (a quantified expression) is reachable from its
      --  nearest enclosing Pre/Post aspect or Assert/Assert_And_Cut/
      --  Loop_Invariant pragma without first passing through an ordinary
      --  statement -- the only positions a quantified expression is ever
      --  evaluated directly (Boolean_Value/VC.Decide), bypassing the
      --  general CFG-based flow-tracking machinery that genuinely cannot
      --  model a quantifier's effect on program state. Used only to
      --  narrow Contains_Unsupported_Semantics's own blacklist entry for
      --  Ada_Quantified_Expr below; a quantified expression used as an
      --  ordinary value elsewhere (an if-condition, an assignment RHS)
      --  must keep disqualifying the whole subprogram, so this is an
      --  explicit allowlist, not a blanket relaxation.
      function In_Assertion_Position
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
         Current : Libadalang.Analysis.Ada_Node := Node.Parent;
      begin
         while not Libadalang.Analysis.Is_Null (Current) loop
            if Current.Kind = Libadalang.Common.Ada_Aspect_Assoc
              and then Normalized_Text (Current.As_Aspect_Assoc.F_Id) in
                "pre" | "post"
            then
               return True;
            elsif Current.Kind = Libadalang.Common.Ada_Pragma_Node
              and then Normalized_Text (Current.As_Pragma_Node.F_Id) in
                "assert" | "assert-and-cut" | "loop-invariant"
            then
               return True;
            elsif Current.Kind in Libadalang.Common.Ada_Stmt then
               return False;
            end if;
            Current := Current.Parent;
         end loop;
         return False;
      exception
         when others =>
            return False;
      end In_Assertion_Position;

      function Contains_Unsupported_Semantics
        (Node : Libadalang.Analysis.Ada_Node'Class;
         Root : Boolean := True) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif not Root
           and then Node.Kind = Libadalang.Common.Ada_Subp_Body
         then
            return False;
         elsif
           (Node.Kind in
              Libadalang.Common.Ada_Allocator
                | Libadalang.Common.Ada_Explicit_Deref
                | Libadalang.Common.Ada_Real_Literal
                | Libadalang.Common.Ada_Floating_Point_Def
                | Libadalang.Common.Ada_Delta_Aggregate
                | Libadalang.Common.Ada_Generic_Subp_Instantiation
                | Libadalang.Common.Ada_Access_Def)
           or else
             (Node.Kind = Libadalang.Common.Ada_Quantified_Expr
              and then not In_Assertion_Position (Node))
         then
            return True;
         elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
            begin
               if Node.As_Call_Expr.F_Name.P_Is_Dispatching_Call then
                  return True;
               end if;
            exception
               when others =>
                  return True;
            end;
         end if;

         for Index in 1 .. Node.Children_Count loop
            if Contains_Unsupported_Semantics
                 (Node.Child (Index), Root => False)
            then
               return True;
            end if;
         end loop;
         return False;
      end Contains_Unsupported_Semantics;

      --  Cleared by the handler below when the fixed-point run aborts:
      --  States and Reachable then describe only the nodes the worklist
      --  happened to reach, so finalization must not read an unprocessed
      --  node as Unreachable or a partially iterated state as a proof.
      --  Fixpoint_Complete marks the point after which they are final, so
      --  a later failure (in postcondition evaluation, say) does not
      --  discard a completed analysis.
      Fixpoint_Complete  : Boolean := False;
      Boundary_Supported : Boolean :=
        CFG.Is_Complete (Graph)
        and then CFG.Is_Well_Formed (Graph)
        and then not Contains_Unsupported_Semantics (Subprogram);

      procedure Seed_Parameters (State : in out Flow_State) is
      begin
         for Param of Subprogram.F_Subp_Spec.P_Params loop
            declare
               Is_Output_Only : constant Boolean :=
                 Param.F_Mode.Kind in Libadalang.Common.Ada_Mode_Out;
               Typ : constant Libadalang.Analysis.Base_Type_Decl :=
                 Param.F_Type_Expr.P_Designated_Type_Decl;
               Bounds : constant Abstract_Range :=
                 (if Libadalang.Analysis.Is_Null (Typ)
                  then Unknown_Range
                  else Type_Range (Typ, State));
            begin
               for Id of Param.F_Ids loop
                  declare
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node (Id);
                  begin
                     Flow_Set_Initialized
                       (State, Key,
                        (if Is_Output_Only
                         then Output_Parameter_Initialization (Param)
                         else Bool_True));
                     if not Is_Output_Only then
                        Flow_Range_Set (State, Key, Bounds);
                     end if;
                  end;
               end loop;
            end;
         end loop;
      exception
         when others =>
            Flow_Havoc_All (State);
      end Seed_Parameters;

      --  Contracts written on a separate spec name the spec's parameter
      --  defining names, while the body's state is keyed by the body's own
      --  (FP-085). Parameter_Pairs lists each body parameter with its spec
      --  counterpart, so contract facts can be carried across. It is empty
      --  unless the spec resolves precisely and conforms parameter by
      --  parameter (same names, modes and type text, in order):
      --  Libadalang's decl-part resolution is not reliable for same-name
      --  overloads, and a wrong pairing would attach one overload's
      --  contract to another's body.
      type Parameter_Pair is record
         Spec_Name : Libadalang.Analysis.Ada_Node;
         Body_Name : Libadalang.Analysis.Ada_Node;
      end record;

      package Parameter_Pair_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Parameter_Pair);

      function Parameter_Pairs return Parameter_Pair_Vectors.Vector is
         type Flat_Parameter is record
            Name      : Libadalang.Analysis.Ada_Node;
            Name_Text : Ada.Strings.Unbounded.Unbounded_String;
            Mode      : Libadalang.Common.Ada_Node_Kind_Type;
            Is_Aliased : Boolean;
            Type_Text : Ada.Strings.Unbounded.Unbounded_String;
         end record;

         package Flat_Vectors is new Ada.Containers.Vectors
           (Index_Type => Positive, Element_Type => Flat_Parameter);

         function Squeezed (Text : String) return String is
            Lowered : constant String :=
              Text_Utils.Normalize_Rule_Name (Text);
            Result  : String (1 .. Lowered'Length);
            Last    : Natural := 0;
         begin
            for C of Lowered loop
               if C not in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
                  Last := Last + 1;
                  Result (Last) := C;
               end if;
            end loop;
            return Result (1 .. Last);
         end Squeezed;

         function Flatten
           (Spec : Libadalang.Analysis.Base_Subp_Spec)
            return Flat_Vectors.Vector
         is
            Result : Flat_Vectors.Vector;
         begin
            for Param of Spec.P_Params loop
               for Id of Param.F_Ids loop
                  Result.Append
                    ((Name      => Libadalang.Analysis.Ada_Node (Id),
                      Name_Text =>
                        Ada.Strings.Unbounded.To_Unbounded_String
                          (Squeezed (Ada_Text.Node_Text (Id))),
                      Mode      =>
                        (if Param.F_Mode.Kind = Libadalang.Common.Ada_Mode_Default
                         then Libadalang.Common.Ada_Mode_In
                         else Param.F_Mode.Kind),
                      Is_Aliased => Param.F_Has_Aliased.P_As_Bool,
                      Type_Text =>
                        Ada.Strings.Unbounded.To_Unbounded_String
                          (Squeezed (Ada_Text.Node_Text (Param.F_Type_Expr)))));
               end loop;
            end loop;
            return Result;
         end Flatten;

         Result    : Parameter_Pair_Vectors.Vector;
         Decl_Part : Libadalang.Analysis.Basic_Decl;
      begin
         --  Resolved here, not in the declarative part, so a Libadalang
         --  property error reaches the handler below instead of escaping
         --  Verify_Subprogram's elaboration and aborting the whole file.
         Decl_Part := Subprogram.P_Decl_Part (Imprecise_Fallback => False);
         if Libadalang.Analysis.Is_Null (Decl_Part)
           or else Decl_Part.Kind not in
             Libadalang.Common.Ada_Subp_Decl
               | Libadalang.Common.Ada_Abstract_Subp_Decl
           or else Squeezed (Ada_Text.Node_Text
                    (Decl_Part.P_Defining_Name))
             /= Squeezed (Ada_Text.Node_Text (Subprogram.P_Defining_Name))
         then
            return Result;
         end if;

         declare
            Spec_Params : constant Flat_Vectors.Vector :=
              Flatten (Decl_Part.As_Basic_Subp_Decl.P_Subp_Decl_Spec);
            Body_Params : constant Flat_Vectors.Vector :=
              Flatten
                (Libadalang.Analysis.Base_Subp_Spec (Subprogram.F_Subp_Spec));
            use type Ada.Containers.Count_Type;
            use type Ada.Strings.Unbounded.Unbounded_String;
         begin
            if Spec_Params.Length /= Body_Params.Length then
               return Result;
            end if;
            for I in 1 .. Natural (Spec_Params.Length) loop
               declare
                  S : constant Flat_Parameter := Spec_Params (I);
                  B : constant Flat_Parameter := Body_Params (I);
               begin
                  if S.Name_Text /= B.Name_Text
                    or else S.Mode /= B.Mode
                    or else S.Is_Aliased /= B.Is_Aliased
                    or else S.Type_Text /= B.Type_Text
                  then
                     Result.Clear;
                     return Result;
                  end if;
                  if S.Name /= B.Name then
                     Result.Append
                       ((Spec_Name => S.Name, Body_Name => B.Name));
                  end if;
               end;
            end loop;
         end;
         return Result;
      exception
         when others =>
            return Parameter_Pair_Vectors.Empty_Vector;
      end Parameter_Pairs;

      --  An out parameter is to be initialized when the subprogram
      --  returns. One obligation for each, at the parameter's own name in
      --  the declaration the caller sees: the state at the normal exit is
      --  the join of every path that returns, so "initialized" there means
      --  on all of them. A parameter that is not is left unproved, never
      --  called an error: Uninitialized_Output reports that, and a
      --  component-wise initialization is not something this model follows.
      procedure Finalize_Output_Parameters is
         function Declared_Name
           (Body_Name : Libadalang.Analysis.Ada_Node)
            return Libadalang.Analysis.Ada_Node
         is
         begin
            for Pair of Parameter_Pairs loop
               if Pair.Body_Name = Body_Name then
                  return Pair.Spec_Name;
               end if;
            end loop;
            return Body_Name;
         end Declared_Name;
      begin
         for Param of Subprogram.F_Subp_Spec.P_Params loop
            if Param.F_Mode.Kind in Libadalang.Common.Ada_Mode_Out then
               for Id of Param.F_Ids loop
                  declare
                     Key    : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node (Id);
                     Anchor : constant Libadalang.Analysis.Ada_Node :=
                       Declared_Name (Key);
                  begin
                     if not Boundary_Supported then
                        Record_Unsupported
                          (Unit, Anchor, Proof.Initialization_Check,
                           "out parameter initialization at exit has not " &
                             "been established");
                     elsif not Reachable (CFG.Normal_Exit (Graph)) then
                        Record_Unreachable
                          (Unit, Anchor, Proof.Initialization_Check,
                           "the subprogram has no reachable normal exit");
                     elsif Flow_Initialization
                             (States (CFG.Normal_Exit (Graph)), Key) =
                           Bool_True
                     then
                        --  proof-path: output-initialization-final
                        Record_Proved_Safe
                          (Unit, Anchor, Proof.Initialization_Check,
                           Proof.Flow_Analysis,
                           "out parameter is initialized at every " &
                             "represented normal exit",
                           "initialization => true", Final => True);
                     else
                        Record_Unproved
                          (Unit, Anchor, Proof.Initialization_Check,
                           Proof.Flow_Analysis,
                           "out parameter is not established as " &
                             "initialized at the normal exit",
                           Imprecision =>
                             "some path to the exit does not assign the " &
                               "whole parameter",
                           Final => True);
                     end if;
                     Proof.Set_Subject
                       (Unit, Anchor, Proof.Initialization_Check, Anchor);
                  end;
               end loop;
            end if;
         end loop;
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Initialization_Check",
               Operation  => "finalize out parameter initialization",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Finalize_Output_Parameters;

      --  A global of mode Output is to be initialized when the subprogram
      --  returns, as an out parameter is. One obligation for each, at its
      --  name in the Global or Refined_Global aspect, which is where
      --  GNATprove reports it, and decided the same way: proved when the
      --  state at the normal exit has the whole object initialized,
      --  unproved otherwise, and for a state abstraction, which is not an
      --  object this model follows.
      procedure Finalize_Output_Globals is
         procedure Check_Item (Item : Libadalang.Analysis.Ada_Node'Class) is
            Key : constant Libadalang.Analysis.Ada_Node :=
              Flow_Referenced_Name (Item);
         begin
            if not Boundary_Supported then
               Record_Unsupported
                 (Unit, Item, Proof.Initialization_Check,
                  "output global initialization at exit has not been " &
                    "established");
            elsif not Reachable (CFG.Normal_Exit (Graph)) then
               Record_Unreachable
                 (Unit, Item, Proof.Initialization_Check,
                  "the subprogram has no reachable normal exit");
            elsif not Libadalang.Analysis.Is_Null (Key)
              and then Flow_Initialization
                         (States (CFG.Normal_Exit (Graph)), Key) =
                       Bool_True
            then
               --  proof-path: output-global-initialization-final
               Record_Proved_Safe
                 (Unit, Item, Proof.Initialization_Check,
                  Proof.Flow_Analysis,
                  "output global is initialized at every represented " &
                    "normal exit",
                  "initialization => true", Final => True);
            else
               Record_Unproved
                 (Unit, Item, Proof.Initialization_Check,
                  Proof.Flow_Analysis,
                  "output global is not established as initialized at " &
                    "the normal exit",
                  Imprecision =>
                    "some path to the exit does not assign the whole " &
                      "object, or it is a state abstraction",
                  Final => True);
            end if;
            if not Libadalang.Analysis.Is_Null (Key) then
               Proof.Set_Subject
                 (Unit, Item, Proof.Initialization_Check, Key);
            end if;
         end Check_Item;

         procedure Check_Items (Node : Libadalang.Analysis.Ada_Node'Class) is
         begin
            if Libadalang.Analysis.Is_Null (Node)
              or else Node.Kind = Libadalang.Common.Ada_Null_Literal
            then
               return;
            elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
               Check_Items (Node.As_Paren_Expr.F_Expr);
            elsif Node.Kind in Libadalang.Common.Ada_Base_Aggregate then
               for Item of Node.As_Base_Aggregate.F_Assocs loop
                  if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
                     Check_Items (Item.As_Aggregate_Assoc.F_R_Expr);
                  end if;
               end loop;
            elsif Node.Kind in Libadalang.Common.Ada_Identifier
                    | Libadalang.Common.Ada_Dotted_Name
            then
               Check_Item (Node);
            end if;
         end Check_Items;

         procedure Check_Aspect (Global : Libadalang.Analysis.Expr) is
         begin
            if Libadalang.Analysis.Is_Null (Global)
              or else Global.Kind not in Libadalang.Common.Ada_Base_Aggregate
            then
               return;
            end if;

            for Item of Global.As_Base_Aggregate.F_Assocs loop
               if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc
                 and then Item.As_Aggregate_Assoc.F_Designators
                            .Children_Count = 1
                 and then Normalized_Text
                            (Item.As_Aggregate_Assoc.F_Designators
                               .Child (1)) = "output"
               then
                  Check_Items (Item.As_Aggregate_Assoc.F_R_Expr);
               end if;
            end loop;
         end Check_Aspect;
      begin
         Check_Aspect (Contract_Expression (Subprogram, "Global"));
         Check_Aspect (Contract_Expression (Subprogram, "Refined_Global"));
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Initialization_Check",
               Operation  => "finalize output global initialization",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Finalize_Output_Globals;

      procedure Transfer_Declaration
        (Node  : Libadalang.Analysis.Ada_Node;
         State : in out Flow_State)
      is
      begin
         if Node.Kind /= Libadalang.Common.Ada_Object_Decl then
            return;
         end if;

         declare
            Decl    : constant Libadalang.Analysis.Object_Decl :=
              Node.As_Object_Decl;
            Default : constant Libadalang.Analysis.Expr :=
              Decl.F_Default_Expr;
         begin
            if Libadalang.Analysis.Is_Null (Default) then
               declare
                  Initialized : constant Abstract_Bool :=
                    Implicit_Initialization (Decl, State);
               begin
                  for Id of Decl.F_Ids loop
                     Flow_Set_Initialized
                       (State, Libadalang.Analysis.Ada_Node (Id), Initialized);
                  end loop;
               end;
               return;
            end if;

            Scan_Expression_For_Flow_Bugs (Unit, Default, State);
            Check_Value_Range
              (Unit, Default, Decl.F_Type_Expr.P_Designated_Type_Decl,
               State, Rules.Known_Range_Check_Failure,
               "initial value is outside the object's subtype range",
               Constraint => Declared_Constraint (Decl.F_Type_Expr, State));

            declare
               Value : constant Abstract_Int :=
                 Integer_Value (Default, State);
               Bool_Value : constant Abstract_Bool :=
                 Boolean_Value (Default, State);
               Bounds : constant Abstract_Range :=
                 Range_Value (Default, State);
            begin
               --  A call in the initial value can write its out and in out
               --  actuals and its global outputs (FP-105).
               Havoc_Effects_In (Default, State);
               for Id of Decl.F_Ids loop
                  declare
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node (Id);
                  begin
                     Flow_Set (State, Key, Value);
                     Flow_Bool_Set (State, Key, Bool_Value);
                     Flow_Range_Set (State, Key, Bounds);
                     Flow_Set_Initialized (State, Key, Bool_True);
                  end;
               end loop;
            end;
         end;
      exception
         when others =>
            Flow_Havoc_All (State);
      end Transfer_Declaration;

      function Source_Node
        (Id : CFG.Node_Id) return Libadalang.Analysis.Ada_Node is
        (CFG.Node_At (Graph, Id).Source);

      function Enclosing_Loop
        (Node : Libadalang.Analysis.Ada_Node'Class)
         return Libadalang.Analysis.Ada_Node
      is
         Current : Libadalang.Analysis.Ada_Node :=
           Libadalang.Analysis.Ada_Node (Node);
      begin
         while not Libadalang.Analysis.Is_Null (Current) loop
            if Current.Kind in
              Libadalang.Common.Ada_While_Loop_Stmt
                | Libadalang.Common.Ada_For_Loop_Stmt
                | Libadalang.Common.Ada_Loop_Stmt
            then
               return Current;
            end if;
            Current := Current.Parent;
         end loop;
         return Libadalang.Analysis.No_Ada_Node;
      exception
         when others =>
            return Libadalang.Analysis.No_Ada_Node;
      end Enclosing_Loop;

      function Header_For
        (Loop_Node : Libadalang.Analysis.Ada_Node) return CFG.Node_Id
      is
      begin
         for Id in 1 .. CFG.Node_Count (Graph) loop
            if CFG.Node_At (Graph, Id).Kind = CFG.Loop_Header_Node
              and then Source_Node (Id) = Loop_Node
            then
               return Id;
            end if;
         end loop;
         return CFG.No_Node;
      end Header_For;

      --  True when every loop-body statement up to and including
      --  Pragma_Node is itself a "loop-invariant" or "loop-variant"
      --  pragma. Ada/SPARK attaches no meaning to the relative order of
      --  the two: a Loop_Invariant preceded only by a Loop_Variant (or
      --  vice versa) is just as much at the loop-head cut point as one
      --  preceded only by other invariants, so both pragma kinds share
      --  this one leading-position check.
      function Is_Leading_Loop_Proof_Pragma
        (Loop_Node   : Libadalang.Analysis.Ada_Node;
         Pragma_Node : Libadalang.Analysis.Ada_Node) return Boolean
      is
         Stmts : constant Libadalang.Analysis.Stmt_List :=
           Loop_Node.As_Base_Loop_Stmt.F_Stmts;
      begin
         for Index in 1 .. Stmts.Children_Count loop
            declare
               Item : constant Libadalang.Analysis.Ada_Node :=
                 Stmts.Child (Index);
            begin
               if Item = Pragma_Node then
                  return True;
               elsif Item.Kind /= Libadalang.Common.Ada_Pragma_Node
                 or else Normalized_Text (Item.As_Pragma_Node.F_Id) not in
                   "loop-invariant" | "loop-variant"
               then
                  return False;
               end if;
            end;
         end loop;
         return False;
      exception
         when others =>
            return False;
      end Is_Leading_Loop_Proof_Pragma;

      procedure Collect_Loop_Invariants
        (Node : Libadalang.Analysis.Ada_Node'Class)
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         end if;

         if Node.Kind = Libadalang.Common.Ada_Pragma_Node
           and then Normalized_Text (Node.As_Pragma_Node.F_Id) =
             "loop-invariant"
         then
            declare
               Pragma_Node : constant Libadalang.Analysis.Pragma_Node :=
                 Node.As_Pragma_Node;
               Condition   : constant Libadalang.Analysis.Expr :=
                 Pragma_Condition (Pragma_Node);
               Loop_Node   : constant Libadalang.Analysis.Ada_Node :=
                 Enclosing_Loop (Node);
               Header      : constant CFG.Node_Id :=
                 Header_For (Loop_Node);
            begin
               if not Libadalang.Analysis.Is_Null (Condition) then
                  Loop_Invariants.Append
                    ((Pragma_Node       =>
                        Libadalang.Analysis.Ada_Node (Pragma_Node),
                      Condition         => Condition,
                      Header            => Header,
                      Leading           =>
                        Header /= CFG.No_Node
                        and then Is_Leading_Loop_Proof_Pragma
                          (Loop_Node,
                           Libadalang.Analysis.Ada_Node (Pragma_Node)),
                      others            => <>));
               end if;
            end;
         elsif Node.Kind = Libadalang.Common.Ada_Pragma_Node
           and then Normalized_Text (Node.As_Pragma_Node.F_Id) =
             "loop-variant"
         then
            declare
               Pragma_Node : constant Libadalang.Analysis.Pragma_Node :=
                 Node.As_Pragma_Node;
               Expression  : constant Libadalang.Analysis.Expr :=
                 Verification_Pragma_Condition (Pragma_Node);
               Loop_Node   : constant Libadalang.Analysis.Ada_Node :=
                 Enclosing_Loop (Node);
               Header      : constant CFG.Node_Id := Header_For (Loop_Node);
               Count       : constant Natural :=
                 Pragma_Node.F_Args.Children_Count;
               Direction   : VC.Loop_Variant_Direction := VC.Decreases;
               Direction_Supported : Boolean := False;
            begin
               if Count = 1 then
                  declare
                     Assoc : constant
                       Libadalang.Analysis.Pragma_Argument_Assoc :=
                         Pragma_Node.F_Args.Child (1)
                           .As_Pragma_Argument_Assoc;
                     Name : constant String := Normalized_Text (Assoc.F_Name);
                  begin
                     if Name = "decreases" then
                        Direction := VC.Decreases;
                        Direction_Supported := True;
                     elsif Name = "increases" then
                        Direction := VC.Increases;
                        Direction_Supported := True;
                     end if;
                  end;
               end if;

               if not Libadalang.Analysis.Is_Null (Expression) then
                  Loop_Variants.Append
                    ((Pragma_Node =>
                        Libadalang.Analysis.Ada_Node (Pragma_Node),
                      Expression => Expression,
                      Header => Header,
                      Leading =>
                        Header /= CFG.No_Node
                        and then Is_Leading_Loop_Proof_Pragma
                          (Loop_Node,
                           Libadalang.Analysis.Ada_Node (Pragma_Node)),
                      Direction => Direction,
                      Direction_Supported => Direction_Supported,
                      others => <>));
               end if;
            end;
         end if;

         for Index in 1 .. Node.Children_Count loop
            if Node.Kind /= Libadalang.Common.Ada_Subp_Body
              or else Libadalang.Analysis.Ada_Node (Node) =
                Libadalang.Analysis.Ada_Node (Subprogram)
            then
               Collect_Loop_Invariants (Node.Child (Index));
            end if;
         end loop;
      end Collect_Loop_Invariants;

      function Invariants_Trusted (Header : CFG.Node_Id) return Boolean is
         Found : Boolean := False;
      begin
         for Item of Loop_Invariants loop
            if Item.Header = Header and then Item.Leading then
               Found := True;
               if Item.Initialization /= VC_Discharged
                 or else Item.Preservation = VC_Not_Discharged
               then
                  return False;
               end if;
            end if;
         end loop;
         return Found;
      end Invariants_Trusted;

      procedure Remember_Inconclusive
        (Stored    : in out VC.VC_Outcome;
         Candidate : VC.VC_Outcome)
      is
      begin
         --  Preserve an explicit unsupported boundary in preference to a
         --  later generic unknown result: it carries the actionable reason
         --  for why this multi-path loop VC could not be discharged.
         if Candidate.Result = VC.VC_Unsupported
           or else Stored.Result /= VC.VC_Unsupported
         then
            Stored := Candidate;
         end if;
      end Remember_Inconclusive;

      procedure Check_Loop_VCs
        (Header  : CFG.Node_Id;
         State   : Flow_State;
         Symbols : VC.Symbolic_State;
         Is_Back : Boolean)
      is
      begin
         for Index in 1 .. Natural (Loop_Invariants.Length) loop
            declare
               Item : Loop_Invariant_Info :=
                 Loop_Invariants.Element (Index);
            begin
               if Item.Header = Header and then Item.Leading then
                  declare
                     Value  : constant Abstract_Bool :=
                       Boolean_Value (Item.Condition, State);
                     Outcome : constant VC.VC_Outcome :=
                       (if Value = Bool_Unknown
                        then VC.Decide (Item.Condition, State, Symbols)
                        else VC.Unknown_Outcome);
                     Result : constant VC.VC_Result := Outcome.Result;
                     Proved : constant Boolean :=
                       Value = Bool_True or else Result = VC.VC_Proved;
                     Method : constant Proof.Analysis_Method :=
                       (if Result = VC.VC_Proved
                        then Proof.External_Prover
                        else Proof.Abstract_Interpretation);
                  begin
                     if Is_Back then
                        if not Proved then
                           Item.Preservation := VC_Not_Discharged;
                           Remember_Inconclusive
                             (Item.Preservation_Outcome, Outcome);
                        elsif Item.Preservation /= VC_Not_Discharged then
                           Item.Preservation := VC_Discharged;
                           Item.Preservation_By := Method;
                        end if;
                     else
                        if not Proved then
                           Item.Initialization := VC_Not_Discharged;
                           Remember_Inconclusive
                             (Item.Initialization_Outcome, Outcome);
                        elsif Item.Initialization /= VC_Not_Discharged then
                           Item.Initialization := VC_Discharged;
                           Item.Initialization_By := Method;
                        end if;
                     end if;
                     Loop_Invariants.Replace_Element (Index, Item);
                  end;
               end if;
            end;
         end loop;
      end Check_Loop_VCs;

      procedure Apply_Loop_Invariants
        (Header  : CFG.Node_Id;
         State   : in out Flow_State;
         Symbols : in out VC.Symbolic_State)
      is
      begin
         if not Invariants_Trusted (Header) then
            return;
         end if;

         for Item of Loop_Invariants loop
            if Item.Header = Header and then Item.Leading then
               declare
                  True_State, False_State : Flow_State;
               begin
                  Narrow_By_Condition
                    (Item.Condition, State, True_State, False_State);
                  State := True_State;
                  Assume_Into
                    (Symbols, Item.Condition, Truth => True, Flow => State);
               end;
            end if;
         end loop;
      end Apply_Loop_Invariants;

      function Invariants_Discharged
        (Header : CFG.Node_Id) return Boolean
      is
         Found : Boolean := False;
      begin
         for Item of Loop_Invariants loop
            if Item.Header = Header and then Item.Leading then
               Found := True;
               if Item.Initialization /= VC_Discharged
                 or else Item.Preservation /= VC_Discharged
               then
                  return False;
               end if;
            end if;
         end loop;
         return Found;
      end Invariants_Discharged;

      function Invariants_Usable_For_Variant
        (Header : CFG.Node_Id) return Boolean
      is
      begin
         for Item of Loop_Invariants loop
            if Item.Header = Header and then Item.Leading
              and then
                (Item.Initialization /= VC_Discharged
                 or else Item.Preservation /= VC_Discharged)
            then
               return False;
            end if;
         end loop;
         return True;
      end Invariants_Usable_For_Variant;

      procedure Havoc_Loop_Writes
        (Loop_Node : Libadalang.Analysis.Ada_Node;
         State     : in out Flow_State)
      is
         procedure Visit (Node : Libadalang.Analysis.Ada_Node'Class) is
         begin
            if Libadalang.Analysis.Is_Null (Node) then
               return;
            elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
               declare
                  Key : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Assigned_Name (Node);
                  Initialized : constant Abstract_Bool :=
                    Flow_Initialization (State, Key);
               begin
                  Flow_Havoc (State, Key);
                  Flow_Set_Initialized (State, Key, Initialized);
               end;
            elsif Libadalang.Analysis.Ada_Node (Node) /=
              Loop_Node
              and then Node.Kind in
                Libadalang.Common.Ada_While_Loop_Stmt
                  | Libadalang.Common.Ada_For_Loop_Stmt
                  | Libadalang.Common.Ada_Loop_Stmt
            then
               return;
            end if;

            for Index in 1 .. Node.Children_Count loop
               Visit (Node.Child (Index));
            end loop;
         end Visit;
      begin
         Visit (Loop_Node);
      end Havoc_Loop_Writes;

      procedure Apply_Invariant_Cutpoint
        (Target  : CFG.Node_Id;
         State   : in out Flow_State;
         Symbols : in out VC.Symbolic_State)
      is
      begin
         if CFG.Node_At (Graph, Target).Kind = CFG.Loop_Header_Node then
            Apply_Loop_Invariants (Target, State, Symbols);
            return;
         end if;

         for Item of Loop_Invariants loop
            if Item.Leading
              and then Source_Node (Target) = Item.Pragma_Node
            then
               Apply_Loop_Invariants (Item.Header, State, Symbols);
               return;
            end if;
         end loop;
      end Apply_Invariant_Cutpoint;

      procedure Enqueue (Id : CFG.Node_Id) is
      begin
         Work.Append (Id);
      end Enqueue;

      --  The part of Decl's Global contract that names what it may write:
      --  the whole aggregate when any association is an output or one this
      --  does not recognize, nothing for "null", a bare input list, or an
      --  aggregate of Input and Proof_In associations only.
      function Global_Outputs
        (Decl : Libadalang.Analysis.Basic_Decl)
         return Libadalang.Analysis.Ada_Node
      is
         Aspect : constant Libadalang.Analysis.Aspect :=
           Decl.P_Get_Aspect
             (Langkit_Support.Text.To_Unbounded_Text
                (Langkit_Support.Text.To_Text ("Global")));
         Value  : Libadalang.Analysis.Expr;
      begin
         if not Libadalang.Analysis.Exists (Aspect) then
            return Libadalang.Analysis.No_Ada_Node;
         end if;
         if Libadalang.Analysis.Is_Null (Libadalang.Analysis.Value (Aspect))
         then
            return Libadalang.Analysis.No_Ada_Node;
         end if;
         Value := Libadalang.Analysis.Value (Aspect).As_Expr;
         if Value.Kind not in Libadalang.Common.Ada_Base_Aggregate
         then
            return Libadalang.Analysis.No_Ada_Node;
         end if;

         for Item of Value.As_Base_Aggregate.F_Assocs loop
            if Item.Kind /= Libadalang.Common.Ada_Aggregate_Assoc
              or else Item.As_Aggregate_Assoc.F_Designators.Children_Count = 0
              or else Normalized_Text
                (Item.As_Aggregate_Assoc.F_Designators.Child (1)) not in
                  "input" | "proof-in"
            then
               return Libadalang.Analysis.Ada_Node (Value);
            end if;
         end loop;
         return Libadalang.Analysis.No_Ada_Node;
      end Global_Outputs;

      --  True when Node lies within the subprogram body under analysis.
      function Inside_Subprogram
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
         Current : Libadalang.Analysis.Ada_Node :=
           Libadalang.Analysis.Ada_Node (Node);
      begin
         while not Libadalang.Analysis.Is_Null (Current) loop
            if Current = Libadalang.Analysis.Ada_Node (Subprogram) then
               return True;
            end if;
            Current := Current.Parent;
         end loop;
         return False;
      end Inside_Subprogram;

      --  Forgets the value of every object declared outside this
      --  subprogram: what code declared elsewhere, with effects that are
      --  not known, can reach. It cannot reach this subprogram's own
      --  objects.
      procedure Havoc_Nonlocal (State : in out Flow_State) is
         Keys : array (1 .. Binding_Count (State)) of
           Libadalang.Analysis.Ada_Node;
      begin
         for Index in Keys'Range loop
            Keys (Index) := Binding_At (State, Index).Decl;
         end loop;
         for Key of Keys loop
            if not Inside_Subprogram (Key) then
               Flow_Forget_Value (State, Key);
            end if;
         end loop;
      end Havoc_Nonlocal;

      --  Removes from State whatever the effectful function calls
      --  evaluated by Target may write.
      procedure Apply_Function_Call_Effects
        (Target : CFG.Node_Id;
         State  : in out Flow_State)
      is
         procedure Forget_Identifiers_In
           (Node : Libadalang.Analysis.Ada_Node'Class) is
         begin
            if Libadalang.Analysis.Is_Null (Node) then
               return;
            elsif Node.Kind = Libadalang.Common.Ada_Identifier then
               Flow_Forget_Value (State, Flow_Referenced_Name (Node));
            end if;
            for Index in 1 .. Node.Children_Count loop
               Forget_Identifiers_In (Node.Child (Index));
            end loop;
         end Forget_Identifiers_In;

         --  An object the call may have written is no longer known to be
         --  uninitialized.
         procedure May_Initialize_Identifiers_In
           (Node : Libadalang.Analysis.Ada_Node'Class) is
         begin
            if Libadalang.Analysis.Is_Null (Node) then
               return;
            elsif Node.Kind = Libadalang.Common.Ada_Identifier then
               declare
                  Key : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Referenced_Name (Node);
               begin
                  if Flow_Initialization (State, Key) = Bool_False then
                     Flow_Set_Initialized (State, Key, Bool_Unknown);
                  end if;
               end;
            end if;
            for Index in 1 .. Node.Children_Count loop
               May_Initialize_Identifiers_In (Node.Child (Index));
            end loop;
         end May_Initialize_Identifiers_In;

         --  A function with an "out" or "in out" parameter writes its
         --  actual. Whether it does on every path is not worked out, so
         --  unlike a procedure call's actual the object is not taken as
         --  initialized: its value is no longer known, and if it was
         --  uninitialized it may no longer be (FP-099).
         procedure Forget_Written_Actuals
           (Call : Libadalang.Analysis.Name) is
         begin
            for Pair of Call.P_Call_Params loop
               if Formal_Is_Writable (Libadalang.Analysis.Param (Pair)) then
                  Forget_Identifiers_In (Libadalang.Analysis.Actual (Pair));
                  May_Initialize_Identifiers_In
                    (Libadalang.Analysis.Actual (Pair));
               end if;
            end loop;
         exception
            when others =>
               Flow_Forget_All_Values (State);
         end Forget_Written_Actuals;
      begin
         for Call of Effectful_Calls (Target) loop
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Call_Declaration (Call);
            begin
               if Adalang_Analyzer.Subprogram_Summaries
                    .Callee_State_Effects_Known (Call)
               then
                  Havoc_Global_Effects (Call, State);
               elsif not Libadalang.Analysis.Is_Null (Decl)
                 and then Has_Aspect (Decl, "Global")
               then
                  --  Collected only because its Global contract names
                  --  outputs: those are what it writes.
                  Forget_Identifiers_In (Global_Outputs (Decl));
               elsif Libadalang.Analysis.Is_Null (Decl)
                 or else Inside_Subprogram (Decl)
               then
                  Flow_Forget_All_Values (State);
               else
                  Havoc_Nonlocal (State);
               end if;
               Forget_Written_Actuals (Call);
            end;
         end loop;
      exception
         when others =>
            Flow_Forget_All_Values (State);
      end Apply_Function_Call_Effects;

      procedure Merge_Into
        (Target : CFG.Node_Id;
         State  : Flow_State;
         Symbols : VC.Symbolic_State;
         Incoming_Kind : CFG.Edge_Kind)
      is
         Incoming_State   : Flow_State := State;
         Incoming_Symbols : VC.Symbolic_State := Symbols;
         Joined           : Flow_State;
         Joined_Symbols   : VC.Symbolic_State;
      begin
         if not Effectful_Calls (Target).Is_Empty then
            Apply_Function_Call_Effects (Target, Incoming_State);
            Incoming_Symbols := VC.Havoc;
         end if;
         if Implicit_Code_Sees_Locals then
            Flow_Forget_All_Values (Incoming_State);
            Incoming_Symbols := VC.Havoc;
         elsif Implicit_Code_May_Run then
            Havoc_Nonlocal (Incoming_State);
            Incoming_Symbols := VC.Havoc;
         end if;
         if Calls_Untrusted (Target) then
            Incoming_Symbols :=
              VC.Forget_Composite_Values
                (Incoming_Symbols, Source_Node (Target));
         end if;

         if CFG.Node_At (Graph, Target).Kind = CFG.Loop_Header_Node then
            if Summary_Mode
              and then Incoming_Kind = CFG.Loop_Back_Edge
              and then Invariants_Discharged (Target)
            then
               return;
            end if;

            if Incoming_Kind /= CFG.Loop_Back_Edge then
               Check_Loop_VCs
                 (Target, Incoming_State, Incoming_Symbols,
                  Is_Back => False);
            end if;

            if Summary_Mode and then Invariants_Discharged (Target) then
               Havoc_Loop_Writes (Source_Node (Target), Incoming_State);
               Incoming_Symbols := VC.Havoc;
            end if;
            Apply_Loop_Invariants
              (Target, Incoming_State, Incoming_Symbols);
         end if;
         Apply_Invariant_Cutpoint
           (Target, Incoming_State, Incoming_Symbols);

         if not Reachable (Target) then
            States (Target) := Incoming_State;
            Symbolic_States (Target) := Incoming_Symbols;
            Reachable (Target) := True;
            Updates (Target) := 1;
            Enqueue (Target);
            return;
         end if;

         if In_Degree (Target) = 1 and then Updates (Target) <= 64 then
            --  The worklist may reach Target before its only predecessor
            --  has its final state, which a join arriving late there then
            --  changes. Joining that with what Target held would keep
            --  nothing the two disagree on, and give objects that are
            --  related in both (Y = X + 1, say) unrelated values.
            Joined := Incoming_State;
            Joined_Symbols := Incoming_Symbols;
         else
            Joined := Flow_Join (States (Target), Incoming_State);
            Joined_Symbols :=
              VC.Join
                (Symbolic_States (Target), Incoming_Symbols, Joined,
                 Merge_Tag => Positive (Target));
         end if;
         if CFG.Node_At (Graph, Target).Kind = CFG.Loop_Header_Node
           and then Updates (Target) >= 3
         then
            Joined := Flow_Widen (States (Target), Joined);
            Joined_Symbols := VC.Array_Bound_Facts (Joined_Symbols);
         end if;
         Apply_Invariant_Cutpoint (Target, Joined, Joined_Symbols);

         if not Flow_Equal (States (Target), Joined)
           or else not VC.Equal (Symbolic_States (Target), Joined_Symbols)
         then
            Updates (Target) := Updates (Target) + 1;
            if Updates (Target) > 64 then
               Flow_Havoc_All (Joined);
               Joined_Symbols := VC.Havoc;
            end if;
            States (Target) := Joined;
            Symbolic_States (Target) := Joined_Symbols;
            Enqueue (Target);
         end if;
      end Merge_Into;

      function Boolean_Condition
        (Node : Libadalang.Analysis.Ada_Node)
         return Libadalang.Analysis.Expr
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return Libadalang.Analysis.No_Expr;
         elsif Node.Kind in Libadalang.Common.Ada_Expr then
            return Node.As_Expr;
         elsif Node.Kind = Libadalang.Common.Ada_Exit_Stmt then
            return Node.As_Exit_Stmt.F_Cond_Expr;
         elsif Node.Kind = Libadalang.Common.Ada_While_Loop_Stmt then
            return
              Node.As_While_Loop_Stmt.F_Spec.As_While_Loop_Spec.F_Expr;
         else
            return Libadalang.Analysis.No_Expr;
         end if;
      exception
         when others =>
            return Libadalang.Analysis.No_Expr;
      end Boolean_Condition;

      --  Fills Effectful_Calls: for every CFG node, the function calls its
      --  own expression evaluates that are not known to leave state alone.
      procedure Collect_Effectful_Calls is
         Max_Depth : constant := Max_Effect_Depth;

         function May_Change_State
           (Call  : Libadalang.Analysis.Name;
            Depth : Natural) return Boolean;

         --  With First_Only, Collect stops at the first call it finds:
         --  enough for a caller that only asks whether there is one.
         procedure Collect
           (Node       : Libadalang.Analysis.Ada_Node'Class;
            Calls      : in out Call_Name_Vectors.Vector;
            Root       : Boolean;
            Depth      : Natural;
            First_Only : Boolean := False);

         --  True unless the body of Decl can be read and does nothing but
         --  compute: no assignment to an object declared outside it, no
         --  procedure call, and no call to a function that may itself
         --  change state.
         function Body_May_Change_State
           (Decl  : Libadalang.Analysis.Basic_Decl;
            Depth : Natural) return Boolean
         is
            Subp_Body : Libadalang.Analysis.Ada_Node :=
              Libadalang.Analysis.No_Ada_Node;

            function Inside_Body
              (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
            is
               Current : Libadalang.Analysis.Ada_Node :=
                 Libadalang.Analysis.Ada_Node (Node);
            begin
               while not Libadalang.Analysis.Is_Null (Current) loop
                  if Current = Subp_Body then
                     return True;
                  end if;
                  Current := Current.Parent;
               end loop;
               return False;
            end Inside_Body;

            function Writes_Outside
              (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
            is
            begin
               if Libadalang.Analysis.Is_Null (Node) then
                  return False;
               elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt then
                  return True;
               elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
                  declare
                     Target : Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node
                         (Node.As_Assign_Stmt.F_Dest);
                  begin
                     --  Down to the object the destination starts from.
                     loop
                        if Target.Kind = Libadalang.Common.Ada_Dotted_Name
                        then
                           Target := Libadalang.Analysis.Ada_Node
                             (Target.As_Dotted_Name.F_Prefix);
                        elsif Target.Kind = Libadalang.Common.Ada_Call_Expr
                        then
                           Target := Libadalang.Analysis.Ada_Node
                             (Target.As_Call_Expr.F_Name);
                        else
                           exit;
                        end if;
                     end loop;
                     if Target.Kind /= Libadalang.Common.Ada_Identifier
                       or else not Inside_Body
                         (Target.As_Name.P_Referenced_Defining_Name)
                     then
                        return True;
                     end if;
                  end;
               end if;

               for Index in 1 .. Node.Children_Count loop
                  if Writes_Outside (Node.Child (Index)) then
                     return True;
                  end if;
               end loop;
               return False;
            end Writes_Outside;

            --  Node's source text in lower case with all white space
            --  removed.
            function Compact_Text
              (Node : Libadalang.Analysis.Ada_Node'Class) return String
            is
               Image  : constant String :=
                 Ada.Characters.Handling.To_Lower (Ada_Text.Node_Text (Node));
               Result : String (1 .. Image'Length);
               Length : Natural := 0;
            begin
               for Item of Image loop
                  if Item not in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
                     Length := Length + 1;
                     Result (Length) := Item;
                  end if;
               end loop;
               return Result (1 .. Length);
            end Compact_Text;

            Calls : Call_Name_Vectors.Vector;
         begin
            if Depth > Max_Depth then
               return True;
            elsif Decl.Kind = Libadalang.Common.Ada_Subp_Renaming_Decl then
               --  A renaming does what the subprogram it renames does.
               return May_Change_State
                 (Decl.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object,
                  Depth + 1);
            elsif Decl.Kind in Libadalang.Common.Ada_Base_Subp_Body then
               Subp_Body := Libadalang.Analysis.Ada_Node (Decl);
            elsif Decl.Kind in Libadalang.Common.Ada_Basic_Subp_Decl then
               --  Libadalang can pair a declaration with the body of a
               --  same-name overload (FP-044), so the body counts only when
               --  its profile is written exactly like the declaration's.
               declare
                  Candidate : constant Libadalang.Analysis.Body_Node :=
                    Decl.P_Body_Part_For_Decl;
               begin
                  if not Libadalang.Analysis.Is_Null (Candidate)
                    and then Candidate.Kind in
                      Libadalang.Common.Ada_Base_Subp_Body
                    and then Compact_Text
                      (Candidate.As_Base_Subp_Body.F_Subp_Spec) =
                      Compact_Text (Decl.As_Basic_Subp_Decl.P_Subp_Decl_Spec)
                  then
                     Subp_Body := Libadalang.Analysis.Ada_Node (Candidate);
                  end if;
               end;
            end if;

            if Libadalang.Analysis.Is_Null (Subp_Body)
              or else Writes_Outside (Subp_Body)
            then
               return True;
            end if;
            Collect
              (Subp_Body, Calls, Root => True, Depth => Depth,
               First_Only => True);
            return not Calls.Is_Empty;
         exception
            when others =>
               return True;
         end Body_May_Change_State;

         --  Body_May_Change_State (Decl, Depth), worked out once for each
         --  declaration and depth in a unit.
         procedure Body_Effect
           (Decl   : Libadalang.Analysis.Basic_Decl;
            Depth  : Natural;
            Result : out Boolean)
         is
            Key      : constant Libadalang.Analysis.Ada_Node :=
              Libadalang.Analysis.Ada_Node (Decl);
            Position : Body_Effect_Maps.Cursor;
         begin
            if Depth > Max_Depth then
               Result := True;
               return;
            end if;
            Position := Body_Effects (Depth).Find (Key);
            if Body_Effect_Maps.Has_Element (Position) then
               Result := Body_Effect_Maps.Element (Position);
            else
               Result := Body_May_Change_State (Decl, Depth);
               Body_Effects (Depth).Include (Key, Result);
            end if;
         end Body_Effect;

         function May_Change_State
           (Call  : Libadalang.Analysis.Name;
            Depth : Natural) return Boolean
         is
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Call_Declaration (Call);
            Body_Changes_State : Boolean;
         begin
            if Libadalang.Analysis.Is_Null (Decl) then
               return True;
            elsif Decl.Kind in Libadalang.Common.Ada_Enum_Literal_Decl
                             | Libadalang.Common.Ada_Synthetic_Char_Enum_Lit
                             | Libadalang.Common.Ada_Synthetic_Subp_Decl
            then
               --  A literal, or a predefined operator or attribute.
               return False;
            end if;

            for Pair of Call.P_Call_Params loop
               if Formal_Is_Writable (Libadalang.Analysis.Param (Pair)) then
                  return True;
               end if;
            end loop;

            if Adalang_Analyzer.Subprogram_Summaries
                 .Callee_State_Effects_Known (Call)
            then
               return Adalang_Analyzer.Subprogram_Summaries
                 .Callee_Global_Write_Count (Call) > 0;
            elsif Has_Aspect (Decl, "Global") then
               return not Libadalang.Analysis.Is_Null (Global_Outputs (Decl));
            end if;
            if In_Pure_Unit (Decl) or else Explicitly_SPARK (Decl) then
               return False;
            end if;
            Body_Effect (Decl, Depth + 1, Body_Changes_State);
            return Body_Changes_State;
         exception
            when others =>
               return True;
         end May_Change_State;

         procedure Collect
           (Node       : Libadalang.Analysis.Ada_Node'Class;
            Calls      : in out Call_Name_Vectors.Vector;
            Root       : Boolean;
            Depth      : Natural;
            First_Only : Boolean := False)
         is
            procedure Collect_In
              (Part : Libadalang.Analysis.Ada_Node'Class) is
            begin
               Collect
                 (Part, Calls, Root => False, Depth => Depth,
                  First_Only => First_Only);
            end Collect_In;

            procedure Collect_Children is
            begin
               for Index in 1 .. Node.Children_Count loop
                  Collect_In (Node.Child (Index));
               end loop;
            end Collect_Children;

            procedure Note (Call : Libadalang.Analysis.Name) is
            begin
               if May_Change_State (Call, Depth) then
                  Calls.Append (Call);
               end if;
               if not Leaves_Everything_Alone (Call) then
                  Untrusted_Calls.Include
                    (Libadalang.Analysis.Ada_Node (Call));
               end if;
            end Note;

            --  A call evaluates the default expression of every formal it
            --  leaves out; which ones those are is not worked out, so all
            --  the callee's defaults count.
            procedure Collect_Defaults (Call : Libadalang.Analysis.Name) is
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Call_Declaration (Call);
            begin
               --  A literal or a predefined operation has no defaults.
               if Libadalang.Analysis.Is_Null (Decl)
                 or else Depth >= Max_Depth
                 or else Decl.Kind in
                   Libadalang.Common.Ada_Enum_Literal_Decl
                     | Libadalang.Common.Ada_Synthetic_Char_Enum_Lit
                     | Libadalang.Common.Ada_Synthetic_Subp_Decl
               then
                  return;
               end if;
               declare
                  Before : constant Ada.Containers.Count_Type := Calls.Length;
               begin
                  for Param of Decl.P_Subp_Spec_Or_Null.P_Params loop
                     Collect
                       (Param.F_Default_Expr, Calls, Root => False,
                        Depth => Depth + 1, First_Only => First_Only);
                  end loop;
                  --  The defaults are written elsewhere: it is this call
                  --  that evaluates them here.
                  if Natural (Calls.Length) /= Natural (Before) then
                     Calls.Append (Call);
                  end if;
               end;
            exception
               when others =>
                  Calls.Append (Call);
            end Collect_Defaults;
         begin
            if Libadalang.Analysis.Is_Null (Node)
              or else Node.Kind in Libadalang.Common.Ada_Defining_Name
                                 | Libadalang.Common.Ada_Aspect_Spec
              or else (First_Only and then not Calls.Is_Empty)
            then
               return;
            end if;

            case Node.Kind is
               when Libadalang.Common.Ada_Call_Stmt =>
                  --  The procedure call itself is the statement's own
                  --  transfer; only its actuals are evaluated before it.
                  if Node.As_Call_Stmt.F_Call.Kind =
                    Libadalang.Common.Ada_Call_Expr
                  then
                     Collect_In
                       (Node.As_Call_Stmt.F_Call.As_Call_Expr.F_Suffix);
                     Collect_Defaults
                       (Node.As_Call_Stmt.F_Call.As_Call_Expr.F_Name);
                  else
                     Collect_Defaults (Node.As_Call_Stmt.F_Call);
                  end if;

               when Libadalang.Common.Ada_Call_Expr =>
                  if Node.As_Call_Expr.P_Kind = Libadalang.Common.Call then
                     Note (Node.As_Call_Expr.F_Name);
                     Collect_Defaults (Node.As_Call_Expr.F_Name);
                     Collect_In (Node.As_Call_Expr.F_Suffix);
                  else
                     Collect_Children;
                  end if;

               when Libadalang.Common.Ada_Identifier
                  | Libadalang.Common.Ada_Dotted_Name =>
                  --  Libadalang does not report the bare name of a
                  --  generic function instance as a call.
                  if Node.As_Name.P_Is_Call
                    or else
                      (not Libadalang.Analysis.Is_Null
                             (Call_Declaration (Node.As_Name))
                       and then Call_Declaration (Node.As_Name).Kind =
                         Libadalang.Common.Ada_Generic_Subp_Instantiation)
                  then
                     Note (Node.As_Name);
                     Collect_Defaults (Node.As_Name);
                  end if;

               when Libadalang.Common.Ada_Attribute_Ref =>
                  Collect_In (Node.As_Attribute_Ref.F_Prefix);
                  Collect_In (Node.As_Attribute_Ref.F_Args);

               when Libadalang.Common.Ada_Bin_Op_Range =>
                  --  A user-defined operator is a function call too; a
                  --  predefined one resolves to no declaration.
                  if not Libadalang.Analysis.Is_Null
                       (Node.As_Bin_Op.F_Op.P_Referenced_Decl)
                  then
                     Note (Node.As_Bin_Op.F_Op.As_Name);
                  end if;
                  Collect_In (Node.As_Bin_Op.F_Left);
                  Collect_In (Node.As_Bin_Op.F_Right);

               when Libadalang.Common.Ada_Un_Op =>
                  if not Libadalang.Analysis.Is_Null
                       (Node.As_Un_Op.F_Op.P_Referenced_Decl)
                  then
                     Note (Node.As_Un_Op.F_Op.As_Name);
                  end if;
                  Collect_In (Node.As_Un_Op.F_Expr);

               when others =>
                  --  A nested declaration other than the node's own is not
                  --  evaluated here.
                  if Root
                    or else Node.Kind not in Libadalang.Common.Ada_Basic_Decl
                  then
                     Collect_Children;
                  end if;
            end case;
         exception
            when others =>
               --  A name that cannot be resolved may be a call to anything.
               if Node.Kind in Libadalang.Common.Ada_Name then
                  Calls.Append (Node.As_Name);
               end if;
         end Collect;
         --  True unless creating, copying and destroying an object of Typ
         --  provably runs no user code: a scalar or access type, or an
         --  array or untagged record built from such types whose component
         --  defaults call nothing that may change state.
         function Type_May_Run_Code
           (Typ   : Libadalang.Analysis.Base_Type_Decl;
            Depth : Natural) return Boolean
         is
            Full : Libadalang.Analysis.Base_Type_Decl := Typ;

            function Components_May_Run_Code
              (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
            is
               Calls : Call_Name_Vectors.Vector;
            begin
               if Libadalang.Analysis.Is_Null (Node) then
                  return False;
               elsif Node.Kind = Libadalang.Common.Ada_Component_Decl then
                  Collect
                    (Node.As_Component_Decl.F_Default_Expr, Calls,
                     Root => True, Depth => Depth);
                  return not Calls.Is_Empty
                    or else Type_May_Run_Code
                      (Node.As_Component_Decl.F_Component_Def.F_Type_Expr
                         .P_Designated_Type_Decl,
                       Depth + 1);
               end if;

               for Index in 1 .. Node.Children_Count loop
                  if Components_May_Run_Code (Node.Child (Index)) then
                     return True;
                  end if;
               end loop;
               return False;
            end Components_May_Run_Code;
         begin
            if Libadalang.Analysis.Is_Null (Full) or else Depth > Max_Depth
            then
               return True;
            end if;
            if Full.P_Is_Private then
               Full := Full.P_Full_View;
               if Libadalang.Analysis.Is_Null (Full) then
                  return True;
               end if;
            end if;

            if Full.P_Is_Discrete_Type or else Full.P_Is_Real_Type
              or else Full.P_Is_Access_Type
            then
               return False;
            elsif Full.P_Is_Array_Type then
               return Type_May_Run_Code (Full.P_Comp_Type, Depth + 1);
            elsif Full.P_Is_Record_Type and then not Full.P_Is_Tagged_Type
            then
               --  Down to the declaration that lists the components.
               while Full.Kind = Libadalang.Common.Ada_Subtype_Decl loop
                  Full :=
                    Full.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
               end loop;
               return Full.Kind not in Libadalang.Common.Ada_Type_Decl
                 or else Full.As_Type_Decl.F_Type_Def.Kind /=
                   Libadalang.Common.Ada_Record_Type_Def
                 or else Components_May_Run_Code (Full);
            end if;
            return True;
         exception
            when others =>
               return True;
         end Type_May_Run_Code;

         --  Sets the Implicit_Code flags from every object of such a type
         --  that Node declares or assigns, within this subprogram but
         --  outside its nested subprograms.
         procedure Note_Implicit_Code
           (Node : Libadalang.Analysis.Ada_Node'Class)
         is
            procedure Note_Type
              (Typ : Libadalang.Analysis.Base_Type_Decl) is
            begin
               if Type_May_Run_Code (Typ, Depth => 0) then
                  Implicit_Code_May_Run := True;
                  if not Libadalang.Analysis.Is_Null (Typ)
                    and then Inside_Subprogram (Typ)
                  then
                     Implicit_Code_Sees_Locals := True;
                  end if;
               end if;
            end Note_Type;
         begin
            if Libadalang.Analysis.Is_Null (Node)
              or else
                (Node.Kind in Libadalang.Common.Ada_Base_Subp_Body
                 and then Libadalang.Analysis.Ada_Node (Node) /=
                   Libadalang.Analysis.Ada_Node (Subprogram))
            then
               return;
            end if;

            begin
               if Node.Kind in Libadalang.Common.Ada_Object_Decl_Range
                 and then Libadalang.Analysis.Is_Null
                   (Node.As_Object_Decl.F_Renaming_Clause)
               then
                  Note_Type
                    (Node.As_Object_Decl.F_Type_Expr.P_Designated_Type_Decl);
               elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
                  Note_Type (Node.As_Assign_Stmt.F_Dest.P_Expression_Type);
               end if;
            exception
               when others =>
                  --  A type that does not resolve is declared elsewhere.
                  Implicit_Code_May_Run := True;
            end;

            for Index in 1 .. Node.Children_Count loop
               Note_Implicit_Code (Node.Child (Index));
            end loop;
         end Note_Implicit_Code;

         --  Enters Calls into Effectful_Call_Reach. A callee declared in
         --  this subprogram, and one that writes an actual, can reach this
         --  subprogram's own objects.
         procedure Register (Calls : Call_Name_Vectors.Vector) is
            function Reach_Of
              (Call : Libadalang.Analysis.Name) return Effect_Reach
            is
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Call_Declaration (Call);
            begin
               if Libadalang.Analysis.Is_Null (Decl)
                 or else Inside_Subprogram (Decl)
               then
                  return Anywhere;
               end if;
               for Pair of Call.P_Call_Params loop
                  if Formal_Is_Writable (Libadalang.Analysis.Param (Pair))
                  then
                     return Anywhere;
                  end if;
               end loop;
               return Outside_Subprogram;
            exception
               when others =>
                  return Anywhere;
            end Reach_Of;
         begin
            for Call of Calls loop
               Effectful_Call_Reach.Include
                 (Libadalang.Analysis.Ada_Node (Call), Reach_Of (Call));
            end loop;
         end Register;
      begin
         Effectful_Call_Reach.Clear;
         Untrusted_Calls.Clear;
         Verified_Subprogram := Libadalang.Analysis.Ada_Node (Subprogram);
         Implicit_Code_May_Run := False;
         Implicit_Code_Sees_Locals := False;
         Note_Implicit_Code (Subprogram);

         for Id in Effectful_Calls'Range loop
            declare
               Source : constant Libadalang.Analysis.Ada_Node :=
                 Source_Node (Id);
               Cond   : constant Libadalang.Analysis.Expr :=
                 Boolean_Condition (Source);
               Own    : Libadalang.Analysis.Ada_Node :=
                 Libadalang.Analysis.No_Ada_Node;
            begin
               Effectful_Calls (Id).Clear;
               if not Libadalang.Analysis.Is_Null (Cond) then
                  Own := Libadalang.Analysis.Ada_Node (Cond);
               elsif Libadalang.Analysis.Is_Null (Source) then
                  Own := Libadalang.Analysis.No_Ada_Node;
               elsif Source.Kind = Libadalang.Common.Ada_For_Loop_Stmt then
                  Own := Libadalang.Analysis.Ada_Node
                    (Source.As_For_Loop_Stmt.F_Spec);
               elsif Source.Kind = Libadalang.Common.Ada_Case_Stmt then
                  Own := Libadalang.Analysis.Ada_Node
                    (Source.As_Case_Stmt.F_Expr);
               elsif Source.Kind = Libadalang.Common.Ada_If_Stmt then
                  Own := Libadalang.Analysis.Ada_Node
                    (Source.As_If_Stmt.F_Cond_Expr);
               elsif Source.Kind not in Libadalang.Common.Ada_Composite_Stmt
                 and then Source.Kind not in
                   Libadalang.Common.Ada_Base_Subp_Body
               then
                  Own := Source;
               end if;
               Collect
                 (Own, Effectful_Calls (Id), Root => True, Depth => 0);
               Register (Effectful_Calls (Id));
               Calls_Untrusted (Id) := Evaluates_Untrusted_Call (Own);
            end;
         end loop;

         --  The contracts are evaluated too, outside the graph.
         declare
            In_Contracts : Call_Name_Vectors.Vector;
         begin
            Collect
              (Contract_Expression (Subprogram, "Pre"), In_Contracts,
               Root => True, Depth => 0);
            Collect
              (Contract_Expression (Subprogram, "Post"), In_Contracts,
               Root => True, Depth => 0);
            Register (In_Contracts);
         end;
      end Collect_Effectful_Calls;

      procedure Seed_For_Loop_Variable
        (Node  : Libadalang.Analysis.Ada_Node;
         State : in out Flow_State)
      is
      begin
         if Node.Kind = Libadalang.Common.Ada_For_Loop_Stmt then
            Enter_Loop_Parameter
              (Node.As_For_Loop_Stmt.F_Spec.As_For_Loop_Spec, State);
         end if;
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Initialization_Check",
               Operation  => "seed for-loop variable state",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Seed_For_Loop_Variable;

      procedure Process_Node (Id : CFG.Node_Id) is
         Node_Info : constant CFG.CFG_Node := CFG.Node_At (Graph, Id);
         Source    : constant Libadalang.Analysis.Ada_Node :=
           Node_Info.Source;
         Input     : constant Flow_State := States (Id);
         Input_Symbols : constant VC.Symbolic_State := Symbolic_States (Id);
         Output    : Flow_State := Input;
         Output_Symbols : VC.Symbolic_State := Input_Symbols;
      begin
         case Node_Info.Kind is
            when CFG.Declaration_Node =>
               Transfer_Declaration (Source, Output);
               if Source.Kind = Libadalang.Common.Ada_Object_Decl
                 and then not Libadalang.Analysis.Is_Null
                   (Source.As_Object_Decl.F_Default_Expr)
               then
                  for Name of Source.As_Object_Decl.F_Ids loop
                     Output_Symbols :=
                       VC.Assign
                         (Output_Symbols,
                          Libadalang.Analysis.Ada_Node (Name),
                          Source.As_Object_Decl.F_Default_Expr, Input);
                  end loop;
               end if;

            when CFG.Statement_Node =>
               if Source.Kind = Libadalang.Common.Ada_Assign_Stmt then
                  Output :=
                    Interpret_Statement (Unit, Source, Input).State;
                  declare
                     Dest : constant Libadalang.Analysis.Name :=
                       Source.As_Assign_Stmt.F_Dest;
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Flow_Assigned_Name (Source);
                  begin
                     if not Libadalang.Analysis.Is_Null (Key) then
                        Output_Symbols :=
                          VC.Assign
                            (Input_Symbols, Key,
                             Source.As_Assign_Stmt.F_Expr, Input);
                     elsif Dest.Kind = Libadalang.Common.Ada_Call_Expr
                       and then Dest.As_Call_Expr.P_Kind in
                         Libadalang.Common.Array_Index
                           | Libadalang.Common.Array_Slice
                     then
                        --  A write to array elements: of scalars, record
                        --  components and array bounds the symbolic state
                        --  knows what it knew. (A scalar that renames or
                        --  overlays an element holds no fact in the first
                        --  place.) The array has another value, and so
                        --  has whatever it is a part of or is reached
                        --  from: which objects those are is not worked
                        --  out.
                        Output_Symbols :=
                          VC.Forget_Composite_Values (Input_Symbols, Source);
                     else
                        Output_Symbols := VC.Havoc;
                     end if;
                     if Dest.Kind = Libadalang.Common.Ada_Call_Expr then
                        Check_Conversion_Or_Index
                          (Unit, Dest.As_Call_Expr, Input, Input_Symbols);
                     end if;
                  end;
               elsif Source.Kind = Libadalang.Common.Ada_Call_Stmt then
                  Check_Call_Precondition
                    (Unit, Source.As_Call_Stmt.F_Call, Input, Input_Symbols);
                  Scan_Expression_For_Flow_Bugs
                    (Unit, Source, Input, Input_Symbols);
                  Output :=
                    Interpret_Statement (Unit, Source, Input).State;
                  Output_Symbols :=
                    With_Call_Postcondition
                      (Symbols_After_Call
                         (Input_Symbols, Source.As_Call_Stmt, Output),
                       Source.As_Call_Stmt, Output);
               elsif Source.Kind = Libadalang.Common.Ada_Pragma_Node then
                  Output :=
                    Interpret_Proof_Pragma
                      (Unit, Source.As_Pragma_Node, Input, Input_Symbols);
                  declare
                     Cond : constant Libadalang.Analysis.Expr :=
                       Pragma_Condition (Source.As_Pragma_Node);
                  begin
                     if not Libadalang.Analysis.Is_Null (Cond) then
                        Output_Symbols :=
                          Assume_Condition
                            (Input_Symbols, Cond, Truth => True, Flow => Input);
                     end if;
                  end;
               elsif Source.Kind in
                 Libadalang.Common.Ada_Return_Stmt
                   | Libadalang.Common.Ada_Raise_Stmt
                 or else Source.Kind in Libadalang.Common.Ada_Expr
               then
                  --  An expression here is that of an expression function.
                  Scan_Expression_For_Flow_Bugs
                    (Unit, Source, Input, Input_Symbols);
               end if;

            when CFG.Condition_Node =>
               declare
                  Cond : constant Libadalang.Analysis.Expr :=
                    Boolean_Condition (Source);
               begin
                  if not Libadalang.Analysis.Is_Null (Cond) then
                     Scan_Expression_For_Flow_Bugs
                       (Unit, Cond, Input, Input_Symbols);
                     Check_Flow_Condition (Unit, Cond, Input);
                  elsif Source.Kind in Libadalang.Common.Ada_Expr then
                     Scan_Expression_For_Flow_Bugs
                       (Unit, Source, Input, Input_Symbols);
                  end if;
               end;

            when CFG.Loop_Header_Node =>
               declare
                  Cond : constant Libadalang.Analysis.Expr :=
                    Boolean_Condition (Source);
               begin
                  if not Libadalang.Analysis.Is_Null (Cond) then
                     Scan_Expression_For_Flow_Bugs
                       (Unit, Cond, Input, Input_Symbols);
                     Check_Flow_Condition (Unit, Cond, Input);
                  elsif Source.Kind = Libadalang.Common.Ada_For_Loop_Stmt then
                     Scan_Expression_For_Flow_Bugs
                       (Unit, Source.As_For_Loop_Stmt.F_Spec, Input,
                        Input_Symbols);
                  end if;
               end;

            when others =>
               null;
         end case;

         for Edge_Index in 1 .. CFG.Edge_Count (Graph) loop
            declare
               Edge : constant CFG.CFG_Edge :=
                 CFG.Edge_At (Graph, Edge_Index);
               Edge_State : Flow_State := Output;
               Edge_Symbols : VC.Symbolic_State := Output_Symbols;
               Propagate  : Boolean := True;
               Cond       : constant Libadalang.Analysis.Expr :=
                 Boolean_Condition (Source);
            begin
               if Edge.From /= Id then
                  goto Continue_Edge;
               end if;

               if Edge.Kind in CFG.Exceptional_Edge | CFG.Raise_Edge then
                  --  A run-time check may fail before or after part of an
                  --  operation's visible effects.  Joining the incoming and
                  --  normal-transfer states retains only facts valid in both
                  --  cases; in particular, a potentially mutating call
                  --  cannot leave stale caller facts in a handler.
                  Edge_State := Flow_Join (Input, Output);
                  Edge_Symbols := VC.Havoc;
               elsif not Libadalang.Analysis.Is_Null (Cond)
                 and then Edge.Kind in
                   CFG.True_Edge | CFG.False_Edge | CFG.Loop_Exit_Edge
               then
                  declare
                     Value : constant Abstract_Bool :=
                       Boolean_Value (Cond, Input);
                     True_State, False_State : Flow_State;
                     Takes_True : constant Boolean :=
                       Edge.Kind in CFG.True_Edge | CFG.Loop_Exit_Edge
                       and then
                         (Source.Kind = Libadalang.Common.Ada_Exit_Stmt
                          or else Edge.Kind = CFG.True_Edge);
                  begin
                     Narrow_By_Condition
                       (Cond, Input, True_State, False_State);
                     if Takes_True then
                        Edge_State := True_State;
                        Edge_Symbols :=
                          Assume_Condition
                            (Input_Symbols, Cond, Truth => True, Flow => Input);
                        Propagate := Value /= Bool_False;
                     else
                        Edge_State := False_State;
                        Edge_Symbols :=
                          Assume_Condition
                            (Input_Symbols, Cond, Truth => False, Flow => Input);
                        Propagate := Value /= Bool_True;
                     end if;
                  end;
               elsif Node_Info.Kind = CFG.Loop_Header_Node
                 and then Source.Kind = Libadalang.Common.Ada_For_Loop_Stmt
                 and then Edge.Kind = CFG.True_Edge
               then
                  --  The body of a loop over a range known to be empty is
                  --  not entered (FP-106).
                  Propagate :=
                    not Loop_Range_Is_Empty
                          (Source.As_For_Loop_Stmt.F_Spec, Output);
                  Seed_For_Loop_Variable (Source, Edge_State);
                  Edge_Symbols := VC.Array_Bound_Facts (Output_Symbols);
                  declare
                     Spec : constant Libadalang.Analysis.For_Loop_Spec :=
                       Source.As_For_Loop_Stmt.F_Spec.As_For_Loop_Spec;
                  begin
                     if Spec.F_Loop_Type.Kind =
                       Libadalang.Common.Ada_Iter_Type_In
                     then
                        Edge_Symbols :=
                          VC.Assume_Loop_Range
                            (Edge_Symbols,
                             Libadalang.Analysis.Ada_Node
                               (Spec.F_Var_Decl.F_Id),
                             Spec.F_Iter_Expr, Edge_State);
                     end if;
                  end;
               elsif Edge.Kind = CFG.Case_Edge
                 and then not Libadalang.Analysis.Is_Null (Edge.Source)
                 and then Edge.Source.Kind =
                   Libadalang.Common.Ada_Case_Stmt_Alternative
                 and then Source.Kind in Libadalang.Common.Ada_Expr
               then
                  --  Nor is an alternative that no value the selector may
                  --  have selects (FP-106).
                  Propagate :=
                    not Case_Alternative_Excluded
                          (Source.As_Expr,
                           Edge.Source.As_Case_Stmt_Alternative.F_Choices,
                           Edge.Source.Parent, Output);
               end if;

               if Propagate then
                  Merge_Into
                    (Edge.To, Edge_State, Edge_Symbols, Edge.Kind);
               end if;

               <<Continue_Edge>>
            end;
         end loop;
      end Process_Node;

      procedure Prove_Loop_Preservation_VCs is
         Checked : Boolean_Array (States'Range) := (others => False);

         procedure Mark_Preservation
           (Header  : CFG.Node_Id;
            State   : Flow_State;
            Symbols : VC.Symbolic_State;
            Path_Supported : Boolean;
            Path_Blocker   : VC.VC_Outcome)
         is
         begin
            for Index in 1 .. Natural (Loop_Invariants.Length) loop
               declare
                  Item : Loop_Invariant_Info :=
                    Loop_Invariants.Element (Index);
               begin
                  if Item.Header = Header and then Item.Leading then
                     if not Path_Supported then
                        Item.Preservation := VC_Not_Discharged;
                        Remember_Inconclusive
                          (Item.Preservation_Outcome, Path_Blocker);
                     else
                        declare
                           Value : constant Abstract_Bool :=
                             Boolean_Value (Item.Condition, State);
                           Outcome : constant VC.VC_Outcome :=
                             (if Value = Bool_Unknown
                              then VC.Decide
                                (Item.Condition, State, Symbols)
                              else VC.Unknown_Outcome);
                           Result : constant VC.VC_Result := Outcome.Result;
                        begin
                           if Value = Bool_True
                             or else Result = VC.VC_Proved
                           then
                              Item.Preservation := VC_Discharged;
                              Item.Preservation_By :=
                                (if Result = VC.VC_Proved
                                 then Proof.External_Prover
                                 else Proof.Abstract_Interpretation);
                           else
                              Item.Preservation := VC_Not_Discharged;
                              Remember_Inconclusive
                                (Item.Preservation_Outcome, Outcome);
                           end if;
                        end;
                     end if;
                     Loop_Invariants.Replace_Element (Index, Item);
                  end if;
               end;
            end loop;
         end Mark_Preservation;

         procedure Mark_Variant_Progress
           (Header         : CFG.Node_Id;
            Before_State   : Flow_State;
            Before_Symbols : VC.Symbolic_State;
            After_State    : Flow_State;
            After_Symbols  : VC.Symbolic_State;
            Path_Supported : Boolean;
            Path_Blocker   : VC.VC_Outcome)
         is
         begin
            for Index in 1 .. Natural (Loop_Variants.Length) loop
               declare
                  Item : Loop_Variant_Info :=
                    Loop_Variants.Element (Index);
               begin
                  if Item.Header = Header and then Item.Leading then
                     if not Path_Supported
                       or else not Item.Direction_Supported
                       or else not Invariants_Usable_For_Variant (Header)
                     then
                        Item.Progress := VC_Not_Discharged;
                        if not Path_Supported then
                           Item.Progress_Outcome := Path_Blocker;
                        end if;
                     else
                        declare
                           Expr_Type : constant
                             Libadalang.Analysis.Base_Type_Decl :=
                               Item.Expression.P_Expression_Type;
                           Bounds : Abstract_Range := Unknown_Range;
                        begin
                           if not Libadalang.Analysis.Is_Null (Expr_Type)
                             and then Expr_Type.P_Is_Int_Type
                           then
                              Bounds := Overflow_Base_Range
                                (Expr_Type, Item.Expression, Before_State);
                              if not Bounds.Has_Low
                                and then not Bounds.Has_High
                              then
                                 Bounds := Type_Range
                                   (Expr_Type, Before_State);
                              end if;
                           end if;

                           Item.Progress_Outcome :=
                             VC.Decide_Variant_Progress
                               (Item.Expression, Item.Direction, Bounds,
                                Before_State, Before_Symbols,
                                After_State, After_Symbols);
                           if Item.Progress_Outcome.Result = VC.VC_Proved then
                              Item.Progress := VC_Discharged;
                              Item.Progress_By := Proof.External_Prover;
                           else
                              Item.Progress := VC_Not_Discharged;
                           end if;
                        end;
                     end if;
                     Loop_Variants.Replace_Element (Index, Item);
                  end if;
               exception
                  when others =>
                     Item.Progress := VC_Not_Discharged;
                     Loop_Variants.Replace_Element (Index, Item);
               end;
            end loop;
         end Mark_Variant_Progress;

         procedure Prove_Header (Header : CFG.Node_Id) is
            State     : Flow_State := States (Header);
            Symbols   : VC.Symbolic_State := VC.Havoc;
            Before_State   : Flow_State := Empty_Flow_State;
            Before_Symbols : VC.Symbolic_State := VC.Havoc;
            Steps     : Natural := 0;

            --  Why Advance (through its Blocker parameter) rejected the
            --  loop path, when the reason is a documented subset boundary
            --  rather than an unsupported node kind. Reported as
            --  unsupported provenance on the preservation and
            --  variant-progress obligations.
            Path_Blocker : VC.VC_Outcome := VC.Unknown_Outcome;

            --  The If_Stmt an elsif/else condition belongs to: Source
            --  itself when Source.Parent is the If_Stmt (the chain's
            --  first, top-level condition), or the If_Stmt reached by
            --  walking Elsif_Stmt_Part -> Elsif_Stmt_Part_List -> If_Stmt
            --  when Source.Parent is an Elsif_Stmt_Part. No_Ada_Node for
            --  anything else (in particular, a top-level while/for/loop
            --  condition, which never continues an elsif chain).
            function Enclosing_If_Stmt
              (Source : Libadalang.Analysis.Ada_Node)
               return Libadalang.Analysis.Ada_Node
            is
               use Libadalang.Common;
            begin
               if Libadalang.Analysis.Is_Null (Source)
                 or else Libadalang.Analysis.Is_Null (Source.Parent)
               then
                  return Libadalang.Analysis.No_Ada_Node;
               elsif Source.Parent.Kind = Ada_If_Stmt then
                  return Source.Parent;
               elsif Source.Parent.Kind = Ada_Elsif_Stmt_Part
                 and then not Libadalang.Analysis.Is_Null
                   (Source.Parent.Parent)
                 and then not Libadalang.Analysis.Is_Null
                   (Source.Parent.Parent.Parent)
                 and then Source.Parent.Parent.Parent.Kind = Ada_If_Stmt
               then
                  return Source.Parent.Parent.Parent;
               else
                  return Libadalang.Analysis.No_Ada_Node;
               end if;
            end Enclosing_If_Stmt;

            --  True exactly when Candidate is an elsif condition
            --  (Elsif_Stmt_Part.F_Cond_Expr) belonging to the same
            --  If_Stmt as Root -- i.e. Candidate continues the same
            --  if/elsif/else chain Root started, rather than being a
            --  lexically distinct, genuinely nested If_Stmt reached via
            --  Root's own False edge (an else body containing its own,
            --  unrelated if statement).
            function Continues_Same_If_Chain
              (Root      : Libadalang.Analysis.Ada_Node;
               Candidate : Libadalang.Analysis.Ada_Node) return Boolean
            is
               use Libadalang.Common;
            begin
               return not Libadalang.Analysis.Is_Null (Root)
                 and then not Libadalang.Analysis.Is_Null (Candidate)
                 and then not Libadalang.Analysis.Is_Null (Candidate.Parent)
                 and then Candidate.Parent.Kind = Ada_Elsif_Stmt_Part
                 and then Enclosing_If_Stmt (Candidate) = Root;
            end Continues_Same_If_Chain;

            --  The Case_Stmt a case-selector expression belongs to, or
            --  No_Ada_Node for anything else. Simpler than
            --  Enclosing_If_Stmt: a case statement never nests at the CFG
            --  level (Build_Statement's Ada_Case_Stmt case lowers to one
            --  Condition_Node per case statement, never a chain), so no
            --  ancestry walk beyond the immediate parent is needed.
            function Enclosing_Case_Stmt
              (Source : Libadalang.Analysis.Ada_Node)
               return Libadalang.Analysis.Ada_Node
            is
               use Libadalang.Common;
            begin
               if Libadalang.Analysis.Is_Null (Source)
                 or else Libadalang.Analysis.Is_Null (Source.Parent)
                 or else Source.Parent.Kind /= Ada_Case_Stmt
               then
                  return Libadalang.Analysis.No_Ada_Node;
               end if;
               return Source.Parent;
            end Enclosing_Case_Stmt;

            --  Single-steps the CFG from Start under the same restricted
            --  rules Prove_Header has always enforced (exactly one
            --  non-exceptional outgoing edge per node; assign/pragma/
            --  merge only). The one addition: at a Condition_Node with
            --  Branch_Budget > 0, fork into both arms. One unit of budget
            --  is spent per independent if/elsif/else chain or case
            --  statement encountered -- an elsif/else part that continues
            --  the same chain (Continues_Same_If_Chain above), or a
            --  sibling alternative of the same case statement, is free,
            --  folding into the same fork-and-join this function already
            --  applies to a single if/else, exactly as before this budget
            --  existed. What *does* spend a unit is any other Condition_Node
            --  reached from an arm's own body (a lexically nested if/case)
            --  or from the chain's own tail once it rejoins (a second,
            --  sequential if/case) -- both look identical to this walker
            --  (just another Condition_Node reached while budget remains),
            --  and both are equally sound to fork on: each arm's own
            --  recursive Advance call must independently reach the loop's
            --  back edge before anything is joined, so nesting one
            --  supported fork inside another composes the same one-level
            --  soundness argument by induction rather than needing a new
            --  one. Starting budget is 2 (see the top-level call below),
            --  so exactly one nested-or-sequential second conditional is
            --  supported beyond the first; a third independent
            --  conditional along any single path exhausts the budget and
            --  is rejected the same way an unsupported node kind always
            --  was. If both arms independently reach the
            --  loop's own back edge, their final states are joined with
            --  the same Flow_Join/VC.Join machinery Merge_Into already
            --  relies on at ordinary CFG merge points. Reached_Back is
            --  True exactly when the walk (directly, or via a successful
            --  fork-and-join) reached the loop back edge; every successful
            --  return sets it, so it never disagrees with the function
            --  result.
            function Advance
              (Start         : CFG.Node_Id;
               Branch_Budget : Natural;
               State         : in out Flow_State;
               Symbols       : in out VC.Symbolic_State;
               Steps         : in out Natural;
               Reached_Back  : out Boolean;
               Blocker       : in out VC.VC_Outcome) return Boolean
            is
               Current : CFG.Node_Id := Start;
               First   : Boolean := True;

               --  Folds a case statement's alternatives into the same
               --  ite-join machinery elsif chains use, via VC.Join_On_Range
               --  in place of VC.Join_On_Condition. Supported subset: every
               --  alternative but a trailing, explicit `others` must have
               --  exactly one choice in F_Choices, with a statically known
               --  interval (Choice_Interval.Known) -- a multi-choice
               --  alternative ("when 1 | 3 =>") or a discontiguous range set
               --  is rejected outright, never range-unioned, since a
               --  covering range would unsoundly admit selector values
               --  belonging to a different (or no) alternative. Each
               --  alternative's own body is walked with the budget already
               --  spent for this case statement (Branch_Budget - 1),
               --  exactly like an if/elsif arm, so a nested if/case inside
               --  any alternative, or a second sequential conditional
               --  following the case statement, draws on the same
               --  remaining budget an equivalent if/elsif/else shape
               --  would. Right-folds from the trailing `others` (the base case,
               --  needing no selector, mirroring elsif's own bare trailing
               --  else) back to the first alternative, one Join_On_Range
               --  call per non-`others` alternative.
               function Advance_Case
                 (Case_Condition        : CFG.Node_Id;
                  Case_Condition_Source : Libadalang.Analysis.Ada_Node)
                  return Boolean
               is
                  use Libadalang.Common;

                  Case_Stmt_Node : constant Libadalang.Analysis.Ada_Node :=
                    Enclosing_Case_Stmt (Case_Condition_Source);
               begin
                  if Libadalang.Analysis.Is_Null (Case_Stmt_Node) then
                     return False;
                  end if;

                  declare
                     CS : constant Libadalang.Analysis.Case_Stmt :=
                       Case_Stmt_Node.As_Case_Stmt;
                     N  : constant Positive := CS.F_Alternatives.Children_Count;

                     function Alt
                       (I : Positive)
                        return Libadalang.Analysis.Case_Stmt_Alternative
                     is (CS.F_Alternatives.Child (I).As_Case_Stmt_Alternative);

                     function Target_For
                       (A : Libadalang.Analysis.Case_Stmt_Alternative)
                        return CFG.Node_Id
                     is
                     begin
                        for Edge_Index in 1 .. CFG.Edge_Count (Graph) loop
                           declare
                              E : constant CFG.CFG_Edge :=
                                CFG.Edge_At (Graph, Edge_Index);
                           begin
                              if E.From = Case_Condition
                                and then E.Kind = CFG.Case_Edge
                                and then E.Source =
                                  Libadalang.Analysis.Ada_Node (A)
                              then
                                 return E.To;
                              end if;
                           end;
                        end loop;
                        return CFG.No_Node;
                     end Target_For;

                     Ranges  : array (1 .. N) of Abstract_Range;
                     Targets : array (1 .. N) of CFG.Node_Id;
                  begin
                     for I in 1 .. N loop
                        declare
                           A : constant
                             Libadalang.Analysis.Case_Stmt_Alternative :=
                               Alt (I);
                        begin
                           if A.F_Choices.Children_Count /= 1 then
                              return False;
                           end if;
                           declare
                              Choice : constant Libadalang.Analysis.Ada_Node :=
                                A.F_Choices.Child (1);
                           begin
                              if Choice.Kind = Ada_Others_Designator then
                                 if I /= N then
                                    return False;
                                 end if;
                              else
                                 if I = N then
                                    return False;
                                 end if;
                                 declare
                                    Interval : constant Static_Interval :=
                                      Choice_Interval (Choice, State);
                                 begin
                                    if not Interval.Known then
                                       return False;
                                    end if;
                                    Ranges (I) :=
                                      (Has_Low => True, Low => Interval.Low,
                                       Has_High => True,
                                       High => Interval.High);
                                 end;
                              end if;
                           end;
                           Targets (I) := Target_For (A);
                           if Targets (I) = CFG.No_Node then
                              return False;
                           end if;
                        end;
                     end loop;

                     declare
                        Acc_State   : Flow_State := State;
                        Acc_Symbols : VC.Symbolic_State := Symbols;
                        Acc_Steps   : Natural := Steps;
                        Acc_Back    : Boolean;
                        Acc_OK      : constant Boolean :=
                          Advance
                            (Targets (N), Branch_Budget - 1, Acc_State,
                             Acc_Symbols, Acc_Steps, Acc_Back, Blocker);
                     begin
                        if not Acc_OK or else not Acc_Back then
                           return False;
                        end if;

                        for I in reverse 1 .. N - 1 loop
                           declare
                              Arm_State   : Flow_State := State;
                              Arm_Symbols : VC.Symbolic_State := Symbols;
                              Arm_Steps   : Natural := Steps;
                              Arm_Back    : Boolean;
                              Arm_OK      : constant Boolean :=
                                Advance
                                  (Targets (I), Branch_Budget - 1, Arm_State,
                                   Arm_Symbols, Arm_Steps, Arm_Back, Blocker);
                           begin
                              if not Arm_OK or else not Arm_Back then
                                 return False;
                              end if;
                              Acc_State :=
                                Flow_Join (Arm_State, Acc_State);
                              Acc_Symbols :=
                                VC.Join_On_Range
                                  (True_Side     => Arm_Symbols,
                                   False_Side    => Acc_Symbols,
                                   Pre_Fork_Side => Symbols,
                                   Selector      => CS.F_Expr,
                                   Bounds        => Ranges (I),
                                   Flow          => Acc_State,
                                   Merge_Tag     =>
                                     Positive (Case_Condition) *
                                       (CFG.Node_Count (Graph) + 1) + I);
                           end;
                        end loop;

                        State := Acc_State;
                        Symbols := Acc_Symbols;
                        Reached_Back := True;
                        return True;
                     end;
                  end;
               end Advance_Case;
            begin
               Reached_Back := False;
               loop
                  if not (First and then Current = Header) then
                     declare
                        Node_Info : constant CFG.CFG_Node :=
                          CFG.Node_At (Graph, Current);
                        Source : constant Libadalang.Analysis.Ada_Node :=
                          Node_Info.Source;
                     begin
                        --  The walk gives a node the effects Merge_Into
                        --  and Process_Node give it: what the functions it
                        --  calls may write, what a procedure call does
                        --  (FP-111).
                        if not Effectful_Calls (Current).Is_Empty then
                           Apply_Function_Call_Effects (Current, State);
                           Symbols := VC.Havoc;
                        end if;
                        if Implicit_Code_Sees_Locals then
                           Flow_Forget_All_Values (State);
                           Symbols := VC.Havoc;
                        elsif Implicit_Code_May_Run then
                           Havoc_Nonlocal (State);
                           Symbols := VC.Havoc;
                        end if;
                        if Calls_Untrusted (Current) then
                           Symbols :=
                             VC.Forget_Composite_Values (Symbols, Source);
                        end if;

                        if Node_Info.Kind = CFG.Statement_Node
                          and then Source.Kind =
                            Libadalang.Common.Ada_Assign_Stmt
                        then
                           declare
                              Key  : constant Libadalang.Analysis.Ada_Node :=
                                Flow_Assigned_Name (Source);
                              Dest : constant Libadalang.Analysis.Name :=
                                Source.As_Assign_Stmt.F_Dest;
                           begin
                              --  An array-element/slice write or a
                              --  pointer-dereference write is never
                              --  symbolically tracked anywhere in this
                              --  engine (Symbol_For has no support for an
                              --  indexed or dereferenced read either), so
                              --  skipping the symbolic update below for
                              --  one of those two shapes leaves no stale
                              --  binding behind. A record-component
                              --  write (Ada_Dotted_Name) is different:
                              --  VC_Prover *does* plant a root for
                              --  Obj.Field reads, so skipping its update
                              --  here would let a later reference resolve
                              --  to the pre-write value -- keep bailing
                              --  for that shape, as for any other
                              --  unresolved destination.
                              if Libadalang.Analysis.Is_Null (Key)
                                and then Dest.Kind not in
                                  Libadalang.Common.Ada_Call_Expr
                                    | Libadalang.Common.Ada_Explicit_Deref
                              then
                                 return False;
                              end if;
                              if not Libadalang.Analysis.Is_Null (Key) then
                                 Symbols :=
                                   VC.Assign
                                     (Symbols, Key,
                                      Source.As_Assign_Stmt.F_Expr, State);
                              elsif Dest.Kind /= Libadalang.Common.Ada_Call_Expr
                                or else Dest.As_Call_Expr.P_Kind not in
                                  Libadalang.Common.Array_Index
                                    | Libadalang.Common.Array_Slice
                              then
                                 --  A write through a dereference: what
                                 --  it changes has no name here.
                                 Symbols := VC.Havoc;
                              else
                                 Symbols :=
                                   VC.Forget_Composite_Values
                                     (Symbols, Source);
                              end if;
                              State :=
                                Interpret_Statement
                                  (Unit, Source, State).State;
                           end;
                        elsif Node_Info.Kind = CFG.Statement_Node
                          and then Source.Kind =
                            Libadalang.Common.Ada_Call_Stmt
                        then
                           State :=
                             Interpret_Statement (Unit, Source, State).State;
                           Symbols :=
                             With_Call_Postcondition
                               (Symbols_After_Call
                                  (Symbols, Source.As_Call_Stmt, State),
                                Source.As_Call_Stmt, State);
                        elsif Node_Info.Kind = CFG.Statement_Node
                          and then Source.Kind =
                            Libadalang.Common.Ada_Goto_Stmt
                        then
                           --  A jump leaves the line of statements this
                           --  walk follows to the back edge.
                           return False;
                        elsif Node_Info.Kind in  --  adalang-analyzer: ignore Empty_Elsif_Body
                          CFG.Statement_Node | CFG.Merge_Node
                        then
                           null;
                        elsif Node_Info.Kind = CFG.Condition_Node then
                           if Branch_Budget = 0 then
                              if Blocker.Result /= VC.VC_Unsupported then
                                 Blocker :=
                                   (Result     => VC.VC_Unsupported,
                                    Provenance =>
                                      (Reason              =>
                                         VC.Branch_Budget_Exceeded,
                                       Blocking_Expression =>
                                         Ada.Strings.Unbounded
                                           .To_Unbounded_String
                                             (Ada_Text.Node_Text
                                                (Node_Info.Source)),
                                       Inline_Path         =>
                                         Ada.Strings.Unbounded
                                           .Null_Unbounded_String));
                              end if;
                              return False;
                           end if;

                           declare
                              True_Target   : CFG.Node_Id := CFG.No_Node;
                              False_Target  : CFG.Node_Id := CFG.No_Node;
                              Other         : Natural := 0;
                              Is_Case_Shape : Boolean := False;
                           begin
                              for Edge_Index in
                                1 .. CFG.Edge_Count (Graph)
                              loop
                                 declare
                                    Edge : constant CFG.CFG_Edge :=
                                      CFG.Edge_At (Graph, Edge_Index);
                                 begin
                                    if Edge.From = Current then
                                       case Edge.Kind is
                                          when CFG.True_Edge =>
                                             True_Target := Edge.To;
                                          when CFG.False_Edge =>
                                             False_Target := Edge.To;
                                          when CFG.Case_Edge =>
                                             Is_Case_Shape := True;
                                          when CFG.Exceptional_Edge  --  adalang-analyzer: ignore Null_Case_Alternative
                                             | CFG.Raise_Edge =>
                                             null;
                                          when others =>
                                             Other := Other + 1;
                                       end case;
                                    end if;
                                 end;
                              end loop;

                              if Is_Case_Shape then
                                 if Other > 0
                                   or else True_Target /= CFG.No_Node
                                   or else False_Target /= CFG.No_Node
                                 then
                                    return False;
                                 end if;
                                 return Advance_Case (Current, Source);
                              end if;

                              if Other > 0
                                or else True_Target = CFG.No_Node
                                or else False_Target = CFG.No_Node
                              then
                                 return False;
                              end if;

                              declare
                                 False_Continues : constant Boolean :=
                                   CFG.Node_At (Graph, False_Target).Kind
                                     = CFG.Condition_Node
                                   and then Continues_Same_If_Chain
                                     (Enclosing_If_Stmt (Source),
                                      CFG.Node_At
                                        (Graph, False_Target).Source);

                                 True_State   : Flow_State := State;
                                 True_Symbols : VC.Symbolic_State := Symbols;
                                 True_Steps   : Natural := Steps;
                                 True_Back    : Boolean;
                                 True_OK      : constant Boolean :=
                                   Advance
                                     (True_Target, Branch_Budget - 1,
                                      True_State, True_Symbols, True_Steps,
                                      True_Back, Blocker);

                                 False_State   : Flow_State := State;
                                 False_Symbols : VC.Symbolic_State :=
                                   Symbols;
                                 False_Steps   : Natural := Steps;
                                 False_Back    : Boolean;
                                 False_OK      : constant Boolean :=
                                   Advance
                                     (False_Target,
                                      (if False_Continues then Branch_Budget
                                       else Branch_Budget - 1),
                                      False_State, False_Symbols,
                                      False_Steps, False_Back, Blocker);
                              begin
                                 if not True_OK or else not False_OK
                                   or else not True_Back
                                   or else not False_Back
                                 then
                                    return False;
                                 end if;

                                 State :=
                                   Flow_Join (True_State, False_State);
                                 Symbols :=
                                   VC.Join_On_Condition
                                     (True_Side     => True_Symbols,
                                      False_Side    => False_Symbols,
                                      Pre_Fork_Side => Symbols,
                                      Condition     => Node_Info.Source,
                                      Flow          => State,
                                      Merge_Tag     => Positive (Current));
                                 Reached_Back := True;
                                 return True;
                              end;
                           end;
                        else
                           return False;
                        end if;
                     end;
                  end if;
                  First := False;

                  Steps := Steps + 1;
                  if Steps > CFG.Node_Count (Graph) then
                     return False;
                  end if;

                  declare
                     Next       : CFG.Node_Id := CFG.No_Node;
                     Candidates : Natural := 0;
                  begin
                     for Edge_Index in 1 .. CFG.Edge_Count (Graph) loop
                        declare
                           Edge : constant CFG.CFG_Edge :=
                             CFG.Edge_At (Graph, Edge_Index);
                        begin
                           if Edge.From = Current
                             and then Edge.Kind not in
                               CFG.Exceptional_Edge
                                 | CFG.Raise_Edge
                                 | CFG.Loop_Exit_Edge
                           then
                              if Current = Header  --  adalang-analyzer: ignore Empty_Then_Body
                                and then Edge.Kind not in
                                  CFG.True_Edge | CFG.Normal_Edge
                              then
                                 null;
                              elsif Edge.Kind = CFG.Loop_Back_Edge
                                and then Edge.To = Header
                              then
                                 Reached_Back := True;
                                 return True;
                              else
                                 Candidates := Candidates + 1;
                                 Next := Edge.To;
                              end if;
                           end if;
                        end;
                     end loop;

                     if Candidates /= 1 or else Next = CFG.No_Node then
                        return False;
                     end if;
                     Current := Next;
                  end;
               end loop;
            end Advance;
         begin
            if not Reachable (Header) then
               return;
            end if;

            Havoc_Loop_Writes (Source_Node (Header), State);
            --  VC.Assume bails to VC.Havoc (a totally empty state) when
            --  the one condition just given to it doesn't translate.
            --  Adopting that unconditionally would let one untranslatable
            --  leading invariant (or the loop guard itself) erase every
            --  assumption already accumulated from this loop's *other*,
            --  independently-translatable leading invariants -- poisoning
            --  their own, otherwise-provable preservation obligations too.
            --  Keeping the prior Symbols instead means the failing
            --  condition simply contributes nothing (the same
            --  conservative, sound outcome as if it had never been
            --  assumed) without erasing what came before it.
            for Item of Loop_Invariants loop
               if Item.Header = Header and then Item.Leading then
                  declare
                     True_State, False_State : Flow_State;
                  begin
                     Narrow_By_Condition
                       (Item.Condition, State, True_State, False_State);
                     State := True_State;
                     Assume_Into
                       (Symbols, Item.Condition, Truth => True,
                        Flow => State);
                  end;
               end if;
            end loop;

            declare
               Cond : constant Libadalang.Analysis.Expr :=
                 Boolean_Condition (Source_Node (Header));
            begin
               if not Libadalang.Analysis.Is_Null (Cond) then
                  declare
                     True_State, False_State : Flow_State;
                  begin
                     Narrow_By_Condition
                       (Cond, State, True_State, False_State);
                     State := True_State;
                     Assume_Into
                       (Symbols, Cond, Truth => True, Flow => State);
                  end;
               end if;
            end;

            Before_State := State;
            Before_Symbols := Symbols;

            declare
               --  2 independent if/elsif/else chains or case statements
               --  along any single path through the loop body: the first
               --  one encountered from Header, plus one more reachable
               --  either by nesting inside one of its arms or
               --  sequentially after it rejoins -- both draw on the same
               --  unit of remaining budget, per Advance's own doc comment.
               --  A third remains outside the supported subset.
               Max_Branch_Depth : constant := 2;

               Reached_Back : Boolean;
               OK           : constant Boolean :=
                 Advance
                   (Header, Branch_Budget => Max_Branch_Depth,
                    State => State, Symbols => Symbols, Steps => Steps,
                    Reached_Back => Reached_Back, Blocker => Path_Blocker);
               Path_OK      : constant Boolean := OK and then Reached_Back;
            begin
               Mark_Preservation
                 (Header, State, Symbols, Path_OK, Path_Blocker);
               Mark_Variant_Progress
                 (Header, Before_State, Before_Symbols, State, Symbols,
                  Path_OK, Path_Blocker);
            end;
         end Prove_Header;
      begin
         for Item of Loop_Invariants loop
            if Item.Leading
              and then Item.Header /= CFG.No_Node
              and then not Checked (Item.Header)
            then
               Checked (Item.Header) := True;
               Prove_Header (Item.Header);
            end if;
         end loop;
         for Item of Loop_Variants loop
            if Item.Leading
              and then Item.Header /= CFG.No_Node
              and then not Checked (Item.Header)
            then
               Checked (Item.Header) := True;
               Prove_Header (Item.Header);
            end if;
         end loop;
      end Prove_Loop_Preservation_VCs;

      function Matching_CFG_Node
        (Node : Libadalang.Analysis.Ada_Node) return CFG.Node_Id
      is
      begin
         for Id in 1 .. CFG.Node_Count (Graph) loop
            if Source_Node (Id) = Node then
               return Id;
            end if;
         end loop;
         return CFG.No_Node;
      end Matching_CFG_Node;

      --  A guarded operand is evaluated in what its guard leaves of the
      --  containing node's state, or not at all (FP-106; see
      --  Narrow_For_Operand). Finalize_Node sets these while it is inside
      --  one, for the node that contains it.
      Operand_Guarded   : Boolean := False;
      Operand_Dead      : Boolean := False;
      Operand_Container : CFG.Node_Id := CFG.No_Node;
      Operand_State     : Flow_State;
      Operand_Symbols   : VC.Symbolic_State;

      --  The state the 'Old prefixes of the postcondition are evaluated
      --  in: the one on entry, once the precondition holds. Known while
      --  the postcondition is finalized. Any other prefix that is
      --  evaluated earlier than where it is written is decided with no
      --  state at all.
      Entry_Known        : Boolean := False;
      Entry_Flow         : Flow_State;
      Entry_Flow_Symbols : VC.Symbolic_State;

      function State_At (Container : CFG.Node_Id) return Flow_State
      is (if Operand_Guarded and then Container = Operand_Container
          then Operand_State
          elsif Container = CFG.No_Node then Empty_Flow_State
          else States (Container));

      function Symbols_At (Container : CFG.Node_Id) return VC.Symbolic_State
      is (if Operand_Guarded and then Container = Operand_Container
          then Operand_Symbols
          elsif Container = CFG.No_Node then VC.Empty_Symbolic_State
          else Symbolic_States (Container));

      --  True when nothing evaluated in Container, or in the guarded
      --  operand being finalized there, is ever evaluated.
      function Unreached (Container : CFG.Node_Id) return Boolean
      is ((Operand_Guarded
           and then Container = Operand_Container
           and then Operand_Dead)
          or else
            (Container /= CFG.No_Node and then not Reachable (Container)));

      procedure Final_Outcome
        (Node       : Libadalang.Analysis.Ada_Node'Class;
         Kind       : Proof.Obligation_Kind;
         Container  : CFG.Node_Id;
         Explanation : String)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported (Unit, Node, Kind, Explanation);
         elsif Unreached (Container) then
            Record_Unreachable
              (Unit, Node, Kind,
               "the containing CFG node is unreachable");
         else
            Record_Unproved
              (Unit, Node, Kind, Proof.Abstract_Interpretation,
               Explanation,
               Imprecision =>
                 "the fixed-point state did not discharge this obligation");
         end if;
      end Final_Outcome;

      --  As Final_Outcome, but for Range_Check specifically: rather than
      --  always defaulting to Unproved, replays Check_Value_Range's own
      --  Proved_Safe/Definite_Error/Unproved determination against
      --  Container's own fully-converged State, marked Final so it
      --  supersedes whatever a premature live recording (made while
      --  Verify_Subprogram's CFG fixed point could still have been
      --  mid-convergence for Container) left behind for the same
      --  obligation (see FP-034, following FP-031's Ada_Identifier fix).
      procedure Finalize_Range_Check
        (Value      : Libadalang.Analysis.Expr'Class;
         Typ        : Libadalang.Analysis.Base_Type_Decl;
         Container  : CFG.Node_Id;
         Rule       : Rules.Rule_Kind;
         Message    : String;
         Constraint : Subtype_Constraint := (others => <>))
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported (Unit, Value, Proof.Range_Check, Message);
         elsif Unreached (Container)
         then
            Record_Unreachable
              (Unit, Value, Proof.Range_Check,
               "the containing CFG node is unreachable");
         else
            Check_Value_Range
              (Unit, Value, Typ,
               State_At (Container),
               Rule, Message,
               Symbols_At (Container),
               Final => True, Constraint => Constraint);
         end if;
      end Finalize_Range_Check;

      --  As Finalize_Range_Check, but for Index_Check via Check_Index_Range
      --  (see FP-035, the same mechanism applied to array indexing).
      procedure Finalize_Index_Check
        (Index_Value : Libadalang.Analysis.Expr'Class;
         Bounds      : Abstract_Range;
         Container   : CFG.Node_Id;
         Indexed     : Libadalang.Analysis.Call_Expr;
         Dimension   : Positive)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Index_Value, Proof.Index_Check,
               "array index safety has not been established");
         elsif Unreached (Container)
         then
            Record_Unreachable
              (Unit, Index_Value, Proof.Index_Check,
               "the containing CFG node is unreachable");
         else
            Check_Index_Range
              (Unit, Index_Value, Bounds,
               State_At (Container),
               Symbols_At (Container),
               Final => True, Indexed => Indexed, Dimension => Dimension);
         end if;
      end Finalize_Index_Check;

      --  The bounds of a slice are to be within the index bounds of the
      --  sliced array, unless the slice is null. One obligation for the
      --  slice, at the name that is sliced, which is where GNATprove
      --  reports it. It is proved when both bounds are shown to be within
      --  the array's bounds, or the slice is shown to be null. It is never
      --  a definite error: a bound outside the array is legal when the
      --  slice turns out null, and that is not decided here.
      procedure Finalize_Slice_Check
        (Slice     : Libadalang.Analysis.Call_Expr;
         Container : CFG.Node_Id)
      is
         Anchor   : constant Libadalang.Analysis.Name := Slice.F_Name;
         Interval : constant Libadalang.Analysis.Ada_Node :=
           Slice.F_Suffix.As_Ada_Node;
      begin
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Anchor, Proof.Range_Check,
               "slice bounds have not been established");
            return;
         elsif Unreached (Container)
         then
            Record_Unreachable
              (Unit, Anchor, Proof.Range_Check,
               "the containing CFG node is unreachable");
            return;
         elsif Interval.Kind /= Libadalang.Common.Ada_Bin_Op
           or else Interval.As_Bin_Op.F_Op.Kind /=
                     Libadalang.Common.Ada_Op_Double_Dot
         then
            Record_Unproved
              (Unit, Anchor, Proof.Range_Check,
               Proof.Abstract_Interpretation,
               "slice bounds are not established as within the array " &
                 "bounds",
               Imprecision =>
                 "the slice range is not written as two bounds",
               Final => True);
            return;
         end if;

         declare
            State   : constant Flow_State :=
              State_At (Container);
            Symbols : constant VC.Symbolic_State :=
              Symbols_At (Container);
            Low     : constant Libadalang.Analysis.Expr :=
              Interval.As_Bin_Op.F_Left;
            High    : constant Libadalang.Analysis.Expr :=
              Interval.As_Bin_Op.F_Right;
            Limits  : constant Abstract_Range :=
              Array_Object_Index_Range (Anchor, 1, State);
            Low_Range  : constant Abstract_Range := Range_Value (Low, State);
            High_Range : constant Abstract_Range := Range_Value (High, State);
            type Containment is (Not_Shown, By_Interval, By_Prover);

            --  How Bound is shown to be within the array's bounds, if it
            --  is.
            function Inside (Bound : Libadalang.Analysis.Expr)
               return Containment
            is
            begin
               if Definitely_Inside_Range (Bound, Limits, State) then
                  return By_Interval;
               elsif VC.Decide_Bounds (Bound, Limits, State, Symbols).Result =
                       VC.VC_Proved
                 or else
                   ((not Limits.Has_Low or else not Limits.Has_High)
                    and then VC.Decide_Index_In_Object
                               (Bound, Anchor, State, Symbols).Result =
                             VC.VC_Proved)
               then
                  return By_Prover;
               end if;
               return Not_Shown;
            end Inside;

            Low_Inside  : constant Containment := Inside (Low);
            High_Inside : constant Containment :=
              (if Low_Inside = Not_Shown then Not_Shown else Inside (High));
            Used_Prover : constant Boolean :=
              Low_Inside = By_Prover or else High_Inside = By_Prover;
         begin
            if Low_Range.Has_Low
              and then High_Range.Has_High
              and then Low_Range.Low > High_Range.High
            then
               --  proof-path: slice-null
               Record_Proved_Safe
                 (Unit, Anchor, Proof.Range_Check,
                  Proof.Abstract_Interpretation,
                  "the slice is null, so its bounds are not checked",
                  "slice low bound is above its high bound", Final => True);
            elsif Low_Inside /= Not_Shown and then High_Inside /= Not_Shown
            then
               --  proof-path: slice-bounds
               Record_Proved_Safe
                 (Unit, Anchor, Proof.Range_Check,
                  (if Used_Prover then Proof.External_Prover
                   else Proof.Abstract_Interpretation),
                  "both slice bounds are within the array index bounds",
                  (if Used_Prover then VC.Evidence
                   else "slice bounds are within array bounds"),
                  Final => True);
            else
               Record_Unproved
                 (Unit, Anchor, Proof.Range_Check,
                  Proof.Abstract_Interpretation,
                  "slice bounds are not established as within the array " &
                    "bounds",
                  Imprecision =>
                    "slice bound and array bound ranges remain inconclusive",
                  Final => True);
            end if;
         end;
      end Finalize_Slice_Check;

      --  What the form of an array value alone says of its length against
      --  that of what it is given to: nothing; that in each dimension it
      --  either has a static length that is the target's or is an
      --  aggregate with an others choice, which has the bounds of what it
      --  is given to; that both lengths are static and the same.
      type Length_Evidence is (No_Evidence, Bounds_Taken, Static_Equal);

      --  The length check of an array that is given to a target: the two
      --  have the same length in each dimension. The obligation is at
      --  Where. Target is what the value is given to, when that is an
      --  array the source names or the range that constrains it; Fixed is
      --  the length of the target when its subtype says it with a number;
      --  Evidence, what the form of the value says. Never a definite
      --  error: lengths known to differ are not proved.
      procedure Record_Length_Match
        (Where      : Libadalang.Analysis.Ada_Node'Class;
         Target     : Libadalang.Analysis.Expr'Class;
         Fixed      : Abstract_Int;
         Value      : Libadalang.Analysis.Expr'Class;
         Dimensions : Positive;
         Container  : CFG.Node_Id;
         Evidence   : Length_Evidence)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Where, Proof.Length_Check,
               "the value has not been established to have the length " &
                 "of its target");
         elsif Unreached (Container) then
            Record_Unreachable
              (Unit, Where, Proof.Length_Check,
               "the containing CFG node is unreachable");
         elsif Evidence = Static_Equal then
            --  proof-path: length-static
            Record_Proved_Safe
              (Unit, Where, Proof.Length_Check,
               Proof.Abstract_Interpretation,
               "the two lengths are static and the same",
               "both lengths are fixed by declarations", Final => True);
         elsif Evidence = Bounds_Taken then
            --  proof-path: length-of-target
            Record_Proved_Safe
              (Unit, Where, Proof.Length_Check,
               Proof.Abstract_Interpretation,
               "an aggregate with an others choice has the bounds of " &
                 "what it is given to",
               "the value takes the bounds of its target", Final => True);
         else
            declare
               --  A length that is a number on one side is asked of the
               --  other, when the two are not both terms: the value of a
               --  call has none, and its subtype may say how long it is.
               Of_Value : constant Abstract_Int :=
                 (if Dimensions = 1 then Static_Array_Length (Value, 1)
                  else Unknown_Int);
               Outcome  : VC.VC_Outcome :=
                 (if not Libadalang.Analysis.Is_Null (Target)
                  then VC.Decide_Same_Length
                    (Target, Value, Dimensions, State_At (Container),
                     Symbols_At (Container))
                  elsif Fixed.Known and then Dimensions = 1
                  then VC.Decide_Length
                    (Value, Fixed.Value, State_At (Container),
                     Symbols_At (Container))
                  else VC.Unknown_Outcome);
            begin
               if Outcome.Result /= VC.VC_Proved
                 and then Of_Value.Known
                 and then not Libadalang.Analysis.Is_Null (Target)
               then
                  Outcome :=
                    VC.Decide_Length
                      (Target, Of_Value.Value, State_At (Container),
                       Symbols_At (Container));
               end if;
               if Outcome.Result = VC.VC_Proved then
                  --  proof-path: length-equal
                  Record_Proved_Safe
                    (Unit, Where, Proof.Length_Check, Proof.External_Prover,
                     "scalar verification condition proves the value has " &
                       "the length of its target",
                     VC.Evidence, Final => True);
               else
                  Record_VC_Unproved
                    (Unit, Where, Proof.Length_Check,
                     Proof.Abstract_Interpretation,
                     "length-check failure is not established, but " &
                       "absence is not proved",
                     "the two lengths are not known to be equal",
                     Outcome, Final => True);
               end if;
            end;
         end if;

         --  A binary operation is reported at its operator, as GNATprove
         --  reports it: the last "&" of a concatenation over several
         --  lines.
         if Where.Kind in Libadalang.Common.Ada_Bin_Op_Range then
            Proof.Set_Position
              (Unit, Where, Proof.Length_Check,
               Langkit_Support.Slocs.Start_Sloc
                 (Where.As_Bin_Op.F_Op.Sloc_Range));
         elsif Where.Kind = Libadalang.Common.Ada_Concat_Op
           and then Where.As_Concat_Op.F_Other_Operands.Children_Count > 0
         then
            Proof.Set_Position
              (Unit, Where, Proof.Length_Check,
               Langkit_Support.Slocs.Start_Sloc
                 (Where.As_Concat_Op.F_Other_Operands.Child
                    (Where.As_Concat_Op.F_Other_Operands.Children_Count)
                    .As_Concat_Operand.F_Operator.Sloc_Range));
         end if;
      end Record_Length_Match;

      --  An array assignment. The value is converted to the subtype of
      --  the target when the target has a constrained one -- a slice, a
      --  component, an object or a formal declared with one -- and that
      --  conversion is checked at the value, unless both lengths are
      --  static and the same. And where the bounds of the target are not
      --  static the assignment has its own check, at the statement. That
      --  is where GNATprove has a length check, and where it has two.
      procedure Finalize_Array_Assignment
        (Stmt      : Libadalang.Analysis.Assign_Stmt;
         Container : CFG.Node_Id)
      is
         Target        : constant Libadalang.Analysis.Expr :=
           Stmt.F_Dest.As_Expr;
         Value         : constant Libadalang.Analysis.Expr := Stmt.F_Expr;
         Dimensions    : constant Natural :=
           Array_Dimensions (Target.P_Expression_Type);
         Target_Static : Boolean := True;
         Same          : Boolean := True;
         Taken         : Boolean := True;
      begin
         if Dimensions = 0
           or else
             (Has_Own_Subtype (Target)
              and then Has_Own_Subtype (Value)
              and then Same_Constrained_Subtype
                         (Target.P_Expression_Type, Value.P_Expression_Type))
         then
            return;
         end if;

         for Dimension in 1 .. Dimensions loop
            declare
               Of_Target : constant Abstract_Int :=
                 Static_Array_Length (Target, Dimension);
               Of_Value  : constant Abstract_Int :=
                 Static_Array_Length (Value, Dimension);
               Fits      : constant Boolean :=
                 (Of_Target.Known and then Of_Value.Known
                  and then Of_Target.Value = Of_Value.Value)
                 or else Takes_Target_Bounds
                           (Aggregate_Of_Dimension (Value, Dimension));
            begin
               if not Of_Target.Known then
                  Target_Static := False;
               end if;
               Same := Same and then Of_Target.Known and then Fits;
               Taken := Taken and then Fits;
            end;
         end loop;

         if Target_Is_Constrained (Target) and then not Same then
            Record_Length_Match
              (Value, Target, Unknown_Int, Value, Dimensions, Container,
               (if Taken then Bounds_Taken else No_Evidence));
         end if;
         if not Target_Static then
            Record_Length_Match
              (Stmt, Target, Unknown_Int, Value, Dimensions, Container,
               (if Taken then Bounds_Taken else No_Evidence));

            --  It is the check of the ":=", and is reported there.
            declare
               Assign : constant Libadalang.Common.Token_Reference :=
                 Libadalang.Common.Next
                   (Stmt.F_Dest.Token_End, Exclude_Trivia => True);
               Place  : constant Langkit_Support.Slocs.Source_Location_Range :=
                 Libadalang.Common.Sloc_Range (Libadalang.Common.Data (Assign));
            begin
               if Libadalang.Common."="
                    (Libadalang.Common.Kind (Libadalang.Common.Data (Assign)),
                     Libadalang.Common.Ada_Assign)
               then
                  Proof.Set_Position
                    (Unit, Stmt, Proof.Length_Check,
                     Langkit_Support.Slocs.Start_Sloc (Place));
               end if;
            end;
         end if;
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Verification",
               Operation  => "finalize array assignment length check",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Finalize_Array_Assignment;

      --  An array given to what is declared with a constrained subtype --
      --  the initial value of an object, the value a function returns, an
      --  actual parameter, the operand of a conversion: checked at the
      --  value, unless both lengths are static and the same. Typ is the
      --  subtype named, Type_Expr how it is written where it is.
      procedure Finalize_Array_Given
        (Typ       : Libadalang.Analysis.Base_Type_Decl;
         Type_Expr : Libadalang.Analysis.Type_Expr'Class;
         Value     : Libadalang.Analysis.Expr'Class;
         Container : CFG.Node_Id)
      is
         Dimensions : constant Natural := Array_Dimensions (Typ);
         Same       : Boolean := True;
         Taken      : Boolean := True;
         First      : Abstract_Int := Unknown_Int;
         Interval   : Libadalang.Analysis.Expr := Libadalang.Analysis.No_Expr;
      begin
         if Libadalang.Analysis.Is_Null (Value)
           or else not Is_Constrained_Array (Typ, Type_Expr)
           or else
             (not Has_Index_Constraint (Type_Expr)
              and then Has_Own_Subtype (Value)
              and then Same_Constrained_Subtype
                         (Typ, Value.P_Expression_Type))
         then
            return;
         end if;

         for Dimension in 1 .. Dimensions loop
            declare
               Declared : constant Abstract_Int :=
                 Declared_Array_Length (Typ, Type_Expr, Dimension);
               Of_Value : constant Abstract_Int :=
                 Static_Array_Length (Value, Dimension);
               Fits     : constant Boolean :=
                 (Declared.Known and then Of_Value.Known
                  and then Declared.Value = Of_Value.Value)
                 or else Takes_Target_Bounds
                           (Aggregate_Of_Dimension (Value, Dimension));
            begin
               if Dimension = 1 then
                  First := Declared;
               end if;
               Same := Same and then Declared.Known and then Fits;
               Taken := Taken and then Fits;
            end;
         end loop;

         if Same then
            return;
         end if;

         --  The range of a constraint written with its two bounds stands
         --  for the target where its length is not a number.
         if Dimensions = 1
           and then not First.Known
           and then Has_Index_Constraint (Type_Expr)
           and then Type_Expr.As_Subtype_Indication.F_Constraint.Kind =
             Libadalang.Common.Ada_Composite_Constraint
         then
            declare
               Item : constant Libadalang.Analysis.Ada_Node :=
                 Type_Expr.As_Subtype_Indication.F_Constraint
                   .As_Composite_Constraint.F_Constraints.Child (1)
                   .As_Composite_Constraint_Assoc.F_Constraint_Expr;
            begin
               if Item.Kind = Libadalang.Common.Ada_Bin_Op then
                  Interval := Item.As_Expr;
               end if;
            end;
         end if;

         Record_Length_Match
           (Value, Interval, First, Value, Dimensions, Container,
            (if Taken then Bounds_Taken else No_Evidence));
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Verification",
               Operation  => "finalize array length check",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Finalize_Array_Given;

      --  "and", "or" and "xor" on arrays check that their operands have
      --  the same length, at the operator, static lengths or not.
      procedure Finalize_Array_Operator
        (Operation : Libadalang.Analysis.Bin_Op;
         Container : CFG.Node_Id)
      is
         Dimensions : Natural;
         Same       : Boolean := True;
      begin
         if Operation.F_Op.Kind not in Libadalang.Common.Ada_Op_And
              | Libadalang.Common.Ada_Op_Or
              | Libadalang.Common.Ada_Op_Xor
           or else Origin_Of_Operator (Operation) /= Predefined
         then
            return;
         end if;

         Dimensions := Array_Dimensions (Operation.F_Left.P_Expression_Type);
         if Dimensions = 0 then
            return;
         end if;

         for Dimension in 1 .. Dimensions loop
            declare
               Left  : constant Abstract_Int :=
                 Static_Array_Length (Operation.F_Left, Dimension);
               Right : constant Abstract_Int :=
                 Static_Array_Length (Operation.F_Right, Dimension);
            begin
               if not Left.Known or else not Right.Known
                 or else Left.Value /= Right.Value
               then
                  Same := False;
               end if;
            end;
         end loop;

         Record_Length_Match
           (Operation.F_Op, Operation.F_Left, Unknown_Int, Operation.F_Right,
            Dimensions, Container,
            (if Same then Static_Equal else No_Evidence));
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Verification",
               Operation  => "finalize array operator length check",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Finalize_Array_Operator;

      --  An array given to a component in a record aggregate that names
      --  the component is given to the component's subtype.
      procedure Finalize_Array_Component
        (Assoc     : Libadalang.Analysis.Aggregate_Assoc;
         Container : CFG.Node_Id)
      is
         --  The component the association names, when it names one: the
         --  choice of an array aggregate names none.
         function Named_Component return Libadalang.Analysis.Basic_Decl is
            Decl : Libadalang.Analysis.Basic_Decl;
         begin
            if Assoc.F_Designators.Children_Count /= 1
              or else Assoc.F_Designators.Child (1).Kind /=
                Libadalang.Common.Ada_Identifier
            then
               return Libadalang.Analysis.No_Basic_Decl;
            end if;
            Decl := Assoc.F_Designators.Child (1).As_Name.P_Referenced_Decl;
            return
              (if not Libadalang.Analysis.Is_Null (Decl)
                 and then Decl.Kind = Libadalang.Common.Ada_Component_Decl
               then Decl
               else Libadalang.Analysis.No_Basic_Decl);
         exception
            when others =>
               return Libadalang.Analysis.No_Basic_Decl;
         end Named_Component;

         Component : constant Libadalang.Analysis.Basic_Decl :=
           Named_Component;
      begin
         if not Libadalang.Analysis.Is_Null (Component) then
            Finalize_Array_Given
              (Designated_Type
                 (Component.As_Component_Decl.F_Component_Def.F_Type_Expr),
               Component.As_Component_Decl.F_Component_Def.F_Type_Expr,
               Assoc.F_R_Expr, Container);
         end if;
      end Finalize_Array_Component;

      --  The value of an actual parameter is to fit the subtype of its
      --  formal on the way in, and what an "out" or "in out" formal holds at
      --  the return is to fit the subtype of the actual. One obligation,
      --  at the actual, which is where GNATprove reports either check. It
      --  is raised for an integer formal, and only where the check is
      --  needed: not when the subtype that receives the value has every
      --  value of the type, nor when the form of the actual alone says it
      --  fits (see Static_Subtype_Range). A compiler removes the check
      --  there and GNATprove has none.
      procedure Finalize_Actual_Check
        (Param     : Libadalang.Analysis.Defining_Name'Class;
         Actual    : Libadalang.Analysis.Expr'Class;
         Container : CFG.Node_Id)
      is
         Mode        : constant Libadalang.Common.Ada_Node_Kind_Type :=
           Formal_Mode (Param);
         Formal_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Formal_Subtype (Param);
         Copied_In   : constant Boolean :=
           Mode /= Libadalang.Common.Ada_Mode_Out;
         Copied_Back : constant Boolean :=
           Mode in Libadalang.Common.Ada_Mode_Out
             | Libadalang.Common.Ada_Mode_In_Out;
         Message     : constant String :=
           "actual parameter is outside the formal's subtype range";

         function Within (Inner, Outer : Abstract_Range) return Boolean
         is (Inner.Has_Low and then Inner.Has_High
             and then Outer.Has_Low and then Outer.Has_High
             and then Outer.Low <= Inner.Low
             and then Inner.High <= Outer.High);
      begin
         if Array_Dimensions (Formal_Type) > 0 then
            --  An array given to a formal of a constrained subtype has
            --  that subtype's length.
            Finalize_Array_Given
              (Formal_Type, Formal_Type_Expr (Param), Actual, Container);
            return;
         elsif Libadalang.Analysis.Is_Null (Formal_Type)
           or else Libadalang.Analysis.Is_Null (Actual)
           or else not Formal_Type.P_Is_Int_Type
         then
            return;
         end if;

         declare
            State  : constant Flow_State := State_At (Container);
            Formal_Range : constant Abstract_Range :=
              Type_Range (Formal_Type, Empty_Flow_State);
            Target : constant Target_Subtype :=
              (if Copied_Back then Stored_Subtype (Actual, State)
               else (Typ => Actual.P_Expression_Type, Constraint => <>));
            Is_Name : constant Boolean :=
              Actual.Kind in Libadalang.Common.Ada_Identifier
                | Libadalang.Common.Ada_Dotted_Name
                | Libadalang.Common.Ada_Call_Expr
                | Libadalang.Common.Ada_Qual_Expr
                | Libadalang.Common.Ada_Explicit_Deref;
            --  The actual is declared with the subtype of the formal.
            Same   : constant Boolean :=
              Is_Name
              and then not Libadalang.Analysis.Is_Null (Target.Typ)
              and then Libadalang.Analysis.Ada_Node (Target.Typ) =
                Libadalang.Analysis.Ada_Node (Formal_Type);
            --  An attribute gives a universal integer, which the type of
            --  the formal need not hold.
            Typed  : constant Boolean :=
              Actual.Kind /= Libadalang.Common.Ada_Attribute_Ref;
            Needed_In : constant Boolean :=
              Copied_In
              and then not Same
              and then not
                (Is_Name and then Is_Subtype_Of (Target.Typ, Formal_Type))
              and then not (Typed and then Covers_Its_Type (Formal_Type))
              and then not Within
                             (Static_Subtype_Range (Actual), Formal_Range);
            Needed_Back : constant Boolean :=
              Copied_Back
              and then
                (if Target.Constraint.Present
                 then not Within (Formal_Range, Target.Constraint.Bounds)
                 else not Same
                   and then not Is_Subtype_Of (Formal_Type, Target.Typ)
                   and then not Covers_Its_Type (Target.Typ)
                   and then not Within
                                  (Formal_Range,
                                   Type_Range
                                     (Target.Typ, Empty_Flow_State)));
         begin
            if Needed_Back
              and then not
                (Needed_In
                 and then Boundary_Supported
                 and then not Unreached (Container)
                 and then Definitely_Outside_Type
                            (Actual, Formal_Type, State))
            then
               --  Nothing is known here of the value the callee leaves in
               --  its formal beyond the subtype of the formal.
               if not Boundary_Supported then
                  Record_Unsupported
                    (Unit, Actual, Proof.Range_Check,
                     "the value given back has not been established to " &
                       "fit the actual parameter");
               elsif Unreached (Container) then
                  Record_Unreachable
                    (Unit, Actual, Proof.Range_Check,
                     "the containing CFG node is unreachable");
               else
                  Record_Unproved
                    (Unit, Actual, Proof.Range_Check,
                     Proof.Abstract_Interpretation,
                     "the value given back is not established to fit the " &
                       "subtype of the actual parameter",
                     Imprecision =>
                       "the formal's subtype is not within the actual's",
                     Final => True);
               end if;
            elsif Needed_In then
               Finalize_Range_Check
                 (Actual, Formal_Type, Container,
                  Rules.Known_Range_Check_Failure, Message);
            end if;
         end;
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Verification",
               Operation  => "finalize actual parameter range check",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Finalize_Actual_Check;

      --  Finalize_Actual_Check for each actual of Call.
      procedure Finalize_Actual_Checks
        (Call      : Libadalang.Analysis.Call_Expr;
         Container : CFG.Node_Id) is
      begin
         for Pair of Call.F_Name.P_Call_Params loop
            Finalize_Actual_Check
              (Libadalang.Analysis.Param (Pair),
               Libadalang.Analysis.Actual (Pair), Container);
         end loop;
      exception
         when Exc : others =>
            Log_Verbose_Once
              ("actual parameters not paired with formals: " &
               Ada.Exceptions.Exception_Message (Exc));
      end Finalize_Actual_Checks;

      --  X'Length is a universal integer. Where the context expects a
      --  value of an integer type it is converted to that type, and the
      --  conversion is checked: against the base range of the type where
      --  the attribute is an operand of one of the type's own operators,
      --  against the subtype anywhere else, the subtype of the formal when
      --  the operator is a function a declaration defines. One obligation,
      --  at the attribute, which is where GNATprove reports the range
      --  check. There is none where the check is that of something else
      --  -- an actual parameter of a call, the operand of a conversion, an
      --  index, a value assigned or given to a declared object -- nor
      --  where there is no conversion to check: a universal context, or a
      --  length that is a static value within the range. That the type has
      --  room for the longest array the index subtype allows does not
      --  remove the check.
      procedure Finalize_Length_Check
        (Attribute : Libadalang.Analysis.Attribute_Ref;
         Container : CFG.Node_Id)
      is
         Message  : constant String :=
           "length is outside the range of the type it is converted to";
         Context  : Libadalang.Analysis.Ada_Node := Attribute.Parent;
         Expected : Libadalang.Analysis.Base_Type_Decl;
         Target   : Libadalang.Analysis.Base_Type_Decl;
         Origin   : Operator_Origin := Predefined;
         Operand  : Boolean;

         --  True for the types of a context that takes the universal
         --  integer as it is.
         function Is_Universal
           (Typ : Libadalang.Analysis.Base_Type_Decl) return Boolean
         is
            Name : constant String :=
              Langkit_Support.Text.To_UTF8
                (Typ.P_Canonical_Fully_Qualified_Name);

            function Starts_With (Start : String) return Boolean
            is (Name'Length >= Start'Length
                and then Name (Name'First .. Name'First + Start'Length - 1) =
                  Start);
         begin
            return Starts_With ("standard.universal_")
              or else Starts_With ("standard.root_");
         end Is_Universal;

         --  The length when a declaration gives the bounds with static
         --  values: it is then a number to a compiler too.
         function Declared_Length return Abstract_Int is
            Dimension : constant Abstract_Int :=
              (if Libadalang.Analysis.Is_Null (Attribute.F_Args)
                 or else Attribute.F_Args.Children_Count = 0
               then Known_Int (1)
               else Integer_Value
                      (Assoc_Expression (Attribute.F_Args, 1),
                       Empty_Flow_State));
            Prefix    : Libadalang.Analysis.Basic_Decl;
            Bounds    : Abstract_Range;
            Span      : Abstract_Int;
         begin
            if not Dimension.Known or else Dimension.Value not in 1 .. 64 then
               return Unknown_Int;
            end if;

            Prefix := Attribute.F_Prefix.P_Referenced_Decl;
            Bounds :=
              (if not Libadalang.Analysis.Is_Null (Prefix)
                 and then Prefix.Kind in Libadalang.Common.Ada_Base_Type_Decl
               then Array_Index_Range
                      (Prefix.As_Base_Type_Decl,
                       Positive (Dimension.Value), Empty_Flow_State)
               else Array_Object_Index_Range
                      (Attribute.F_Prefix,
                       Positive (Dimension.Value), Empty_Flow_State));
            if not Bounds.Has_Low or else not Bounds.Has_High then
               return Unknown_Int;
            elsif Bounds.Low > Bounds.High then
               return Known_Int (0);
            end if;

            Span := Safe_Sub (Bounds.High, Bounds.Low);
            return
              (if Span.Known then Safe_Add (Span.Value, 1) else Unknown_Int);
         exception
            when others =>
               return Unknown_Int;
         end Declared_Length;

         --  True when the static length Value needs no check against
         --  Target: a value outside the base range of its type is not
         --  legal, one outside the subtype is an error to report.
         function Fits (Value : Long_Long_Integer) return Boolean is
            Bounds : Abstract_Range;
         begin
            if Operand and then Origin = Predefined then
               return True;
            elsif Libadalang.Analysis.Is_Null (Target) then
               return False;
            end if;
            Bounds := Type_Range (Target, Empty_Flow_State);
            return Bounds.Has_Low and then Bounds.Has_High
              and then Value in Bounds.Low .. Bounds.High;
         end Fits;
      begin
         if Normalized_Text (Attribute.F_Attribute) /= "length" then
            return;
         end if;

         while not Libadalang.Analysis.Is_Null (Context)
           and then Context.Kind = Libadalang.Common.Ada_Paren_Expr
         loop
            Context := Context.Parent;
         end loop;

         if Libadalang.Analysis.Is_Null (Context)
           or else Context.Kind in Libadalang.Common.Ada_Assign_Stmt
             | Libadalang.Common.Ada_Object_Decl
             | Libadalang.Common.Ada_Param_Assoc
             | Libadalang.Common.Ada_Call_Expr
         then
            return;
         end if;

         begin
            Expected := Attribute.P_Expected_Expression_Type;
            if Libadalang.Analysis.Is_Null (Expected)
              or else not Expected.P_Is_Int_Type
              or else Is_Universal (Expected)
              or else Attribute.P_Is_Static_Expr
            then
               return;
            end if;
         exception
            when others =>
               return;
         end;

         Operand :=
           Context.Kind in Libadalang.Common.Ada_Bin_Op_Range
             | Libadalang.Common.Ada_Un_Op
             | Libadalang.Common.Ada_Membership_Expr;
         if Operand then
            Origin := Origin_Of_Operator (Context);
         end if;
         Target :=
           (if not Operand or else Origin = Declared then Expected
            elsif Origin = Predefined then Base_Range_Type (Expected)
            else Libadalang.Analysis.No_Base_Type_Decl);

         declare
            Length : constant Abstract_Int := Declared_Length;
         begin
            if Length.Known and then Fits (Length.Value) then
               return;
            end if;
         end;

         if Libadalang.Analysis.Is_Null (Target) then
            --  Nothing says what range the value is to be in.
            if not Boundary_Supported then
               Record_Unsupported
                 (Unit, Attribute, Proof.Range_Check, Message);
            elsif Unreached (Container) then
               Record_Unreachable
                 (Unit, Attribute, Proof.Range_Check,
                  "the containing CFG node is unreachable");
            elsif Origin = Predefined
              and then Definitely_Inside_Range
                         (Attribute, Least_Base_Range (Expected),
                          State_At (Container))
            then
               --  proof-path: length-base-range
               Record_Proved_Safe
                 (Unit, Attribute, Proof.Range_Check,
                  Proof.Abstract_Interpretation,
                  "the length is within the range the type is declared " &
                    "with, which the base range of the type has whatever " &
                    "the implementation",
                  "value bounds are within the declared range of the type",
                  Final => True);
            else
               Record_Unproved
                 (Unit, Attribute, Proof.Range_Check,
                  Proof.Abstract_Interpretation,
                  "the length is not established to be within the range " &
                    "of the type it is converted to",
                  Imprecision =>
                    (if Origin = Unresolved
                     then "the operation the length is an operand of " &
                       "could not be resolved"
                     else "the base range of the type is chosen by the " &
                       "implementation"),
                  Final => True);
            end if;
            return;
         end if;

         Finalize_Range_Check
           (Attribute, Target, Container,
            Rules.Known_Range_Check_Failure, Message);
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Verification",
               Operation  => "finalize length range check",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Finalize_Length_Check;

      --  As Finalize_Range_Check, for Division_By_Zero_Check via
      --  Check_Division_By_Zero (see FP-036).
      procedure Finalize_Division_Check
        (Expr      : Libadalang.Analysis.Bin_Op;
         Container : CFG.Node_Id)
      is
      begin
         if Expr.F_Op not in Libadalang.Common.Ada_Op_Div
             | Libadalang.Common.Ada_Op_Mod
             | Libadalang.Common.Ada_Op_Rem
           or else Origin_Of_Operator (Expr) = Declared
         then
            return;
         end if;

         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
               "zero has not been excluded from the divisor");
         elsif Unreached (Container)
         then
            Record_Unreachable
              (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
               "the containing CFG node is unreachable");
         else
            Check_Division_By_Zero
              (Unit, Expr,
               State_At (Container),
               Symbols_At (Container),
               Final => True);
         end if;
      end Finalize_Division_Check;

      --  As Finalize_Division_Check, for Integer_Overflow_Check via
      --  Check_Integer_Overflow (see FP-037).
      procedure Finalize_Overflow_Check
        (Expr      : Libadalang.Analysis.Bin_Op;
         Container : CFG.Node_Id)
      is
      begin
         if Expr.F_Op not in
           Libadalang.Common.Ada_Op_Plus
             | Libadalang.Common.Ada_Op_Minus
             | Libadalang.Common.Ada_Op_Mult
             | Libadalang.Common.Ada_Op_Div
             | Libadalang.Common.Ada_Op_Pow
           or else Origin_Of_Operator (Expr) = Declared
         then
            return;
         end if;

         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Expr, Proof.Integer_Overflow_Check,
               "overflow safety has not been established");
         elsif Unreached (Container)
         then
            Record_Unreachable
              (Unit, Expr, Proof.Integer_Overflow_Check,
               "the containing CFG node is unreachable");
         else
            Check_Integer_Overflow
              (Unit, Expr,
               State_At (Container),
               Symbols_At (Container),
               Final => True);
         end if;
      end Finalize_Overflow_Check;

      --  As Finalize_Range_Check, for Assertion_Check via
      --  Check_Proof_Pragma_Assertion, covering pragma Assert and the
      --  per-visit condition check shared by pragma Loop_Invariant /
      --  Loop_Variant (see FP-032, the same mechanism applied to
      --  Interpret_Proof_Pragma's live recording).
      procedure Finalize_Assertion_Check
        (Cond      : Libadalang.Analysis.Expr;
         Container : CFG.Node_Id)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Cond, Proof.Assertion_Check,
               "assertion has not been established");
         elsif Unreached (Container)
         then
            Record_Unreachable
              (Unit, Cond, Proof.Assertion_Check,
               "the containing CFG node is unreachable");
         else
            Check_Proof_Pragma_Assertion
              (Unit, Cond,
               State_At (Container),
               Symbols_At (Container),
               Final => True);
         end if;
      end Finalize_Assertion_Check;

      --  As Finalize_Range_Check, for Precondition_Check via
      --  Check_Call_Precondition (see FP-033, the same mechanism applied
      --  to a call's precondition). A call statement's precondition is
      --  live-recorded twice under two distinct stable IDs -- once for
      --  the whole call (Process_Node's Ada_Call_Stmt handling, with the
      --  full symbolic state) and once for just the callee name
      --  (Scan_Expression_For_Flow_Bugs's own Ada_Call_Expr case, reached
      --  by its generic recursion over the same call statement, without
      --  symbols) -- so both must be replayed, not just one.
      --  The obligation is recorded at Callee: the call, its name or, for
      --  an operator a declaration defines, the operator.
      procedure Finalize_Precondition_At
        (Callee    : Libadalang.Analysis.Name'Class;
         Container : CFG.Node_Id)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Callee, Proof.Precondition_Check,
               "call precondition has not been established");
         elsif Unreached (Container)
         then
            Record_Unreachable
              (Unit, Callee, Proof.Precondition_Check,
               "the containing CFG node is unreachable");
         else
            Check_Call_Precondition
              (Unit, Callee, State_At (Container), Symbols_At (Container),
               Final => True);
         end if;
      end Finalize_Precondition_At;

      procedure Finalize_Precondition_Check
        (Call      : Libadalang.Analysis.Call_Expr;
         Container : CFG.Node_Id)
      is
      begin
         Finalize_Precondition_At (Call, Container);
         Finalize_Precondition_At (Call.F_Name, Container);
      end Finalize_Precondition_Check;

      --  An operation whose operator a declaration defines is a call of
      --  that function, and its precondition an obligation like that of
      --  any call: at the operator, which is where GNATprove reports it.
      procedure Finalize_Operator_Call
        (Operator  : Libadalang.Analysis.Op;
         Container : CFG.Node_Id)
      is
         Decl : Libadalang.Analysis.Basic_Decl;
      begin
         if Origin_Of_Operator (Operator.Parent) /= Declared then
            return;
         end if;

         Decl := Call_Declaration (Operator);
         if not Libadalang.Analysis.Is_Null (Decl)
           and then not Libadalang.Analysis.Is_Null
                          (Contract_Expression (Decl, "Pre"))
         then
            Finalize_Precondition_At (Operator, Container);
         end if;
      end Finalize_Operator_Call;

      procedure Finalize_Loop_Invariant
        (Condition : Libadalang.Analysis.Expr;
         Container : CFG.Node_Id)
      is
      begin
         for Item of Loop_Invariants loop
            if Libadalang.Analysis.Ada_Node (Item.Condition) =
              Libadalang.Analysis.Ada_Node (Condition)
            then
               if not Boundary_Supported then
                  Record_Unsupported
                    (Unit, Condition, Proof.Loop_Invariant_Initialization,
                     "loop invariant initialization is outside the bounded " &
                       "verification subset");
                  Record_Unsupported
                    (Unit, Condition, Proof.Loop_Invariant_Preservation,
                     "loop invariant preservation is outside the bounded " &
                       "verification subset");
               elsif not Item.Leading then
                  Record_Unproved
                    (Unit, Condition, Proof.Loop_Invariant_Initialization,
                     Proof.No_Analysis,
                     "only leading loop invariants currently generate " &
                       "inductive verification conditions",
                     Imprecision =>
                       "the invariant is not at the loop-head cut point");
                  Record_Unproved
                    (Unit, Condition, Proof.Loop_Invariant_Preservation,
                     Proof.No_Analysis,
                     "only leading loop invariants currently generate " &
                       "inductive verification conditions",
                     Imprecision =>
                       "the invariant is not at the loop-head cut point");
               elsif Item.Initialization = VC_Discharged then
                  --  proof-path: loop-invariant-initialization
                  Record_Proved_Safe
                    (Unit, Condition,
                     Proof.Loop_Invariant_Initialization,
                     Item.Initialization_By,
                     "the invariant holds on every represented entry to " &
                       "the loop",
                     (if Item.Initialization_By = Proof.External_Prover
                      then VC.Evidence
                      else "loop entry state => invariant"));
               elsif Item.Initialization = Not_Seen
                 or else
                   (Item.Header /= CFG.No_Node
                    and then not Reachable (Item.Header))
               then
                  Record_Unreachable
                    (Unit, Condition,
                     Proof.Loop_Invariant_Initialization,
                     "the loop head has no represented entry");
               else
                  Record_VC_Unproved
                    (Unit, Condition,
                     Proof.Loop_Invariant_Initialization,
                     Proof.Abstract_Interpretation,
                     "the loop-entry state does not establish the invariant",
                     "the scalar loop initialization VC was not discharged",
                     Item.Initialization_Outcome);
               end if;

               if Boundary_Supported and then Item.Leading then
                  if Item.Preservation = VC_Discharged then
                     --  proof-path: loop-invariant-preservation
                     Record_Proved_Safe
                       (Unit, Condition,
                        Proof.Loop_Invariant_Preservation,
                        Item.Preservation_By,
                        "one arbitrary represented iteration preserves the " &
                          "invariant",
                        (if Item.Preservation_By = Proof.External_Prover
                         then VC.Evidence
                         else "invariant and loop body => invariant"));
                  elsif Item.Preservation = Not_Seen then
                     Record_Unreachable
                       (Unit, Condition,
                        Proof.Loop_Invariant_Preservation,
                        "no represented loop back edge is reachable");
                  else
                     Record_VC_Unproved
                       (Unit, Condition,
                        Proof.Loop_Invariant_Preservation,
                        Proof.Abstract_Interpretation,
                        "the loop body does not establish invariant " &
                          "preservation",
                        "the scalar loop preservation VC was not discharged",
                        Item.Preservation_Outcome);
                  end if;
               end if;
               return;
            end if;
         end loop;

         Final_Outcome
           (Condition, Proof.Loop_Invariant_Initialization, Container,
            "loop invariant initialization is not discharged");
         Final_Outcome
           (Condition, Proof.Loop_Invariant_Preservation, Container,
            "loop invariant preservation is not discharged");
      end Finalize_Loop_Invariant;

      procedure Finalize_Loop_Variant
        (Expression : Libadalang.Analysis.Expr;
         Container  : CFG.Node_Id)
      is
      begin
         for Item of Loop_Variants loop
            if Libadalang.Analysis.Ada_Node (Item.Expression) =
              Libadalang.Analysis.Ada_Node (Expression)
            then
               if not Boundary_Supported then
                  Record_Unsupported
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     "loop-variant progress is outside the bounded " &
                       "verification subset");
               elsif not Item.Leading then
                  Record_Unproved
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Proof.No_Analysis,
                     "only a leading loop variant currently generates a " &
                       "termination verification condition",
                     Imprecision =>
                       "the variant is not at the loop-head cut point");
               elsif not Item.Direction_Supported then
                  Record_Unproved
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Proof.No_Analysis,
                     "the loop-variant direction is unsupported",
                     Imprecision =>
                       "exactly one Increases or Decreases component is " &
                         "required");
               elsif Item.Progress = VC_Discharged then
                  --  proof-path: loop-variant-progress
                  Record_Proved_Safe
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Item.Progress_By,
                     "one arbitrary represented iteration makes strict, " &
                       "bounded progress",
                     VC.Evidence);
               elsif Item.Progress = Not_Seen
                 or else
                   (Item.Header /= CFG.No_Node
                    and then not Reachable (Item.Header))
               then
                  Record_Unreachable
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     "no represented loop iteration is reachable");
               elsif Item.Progress_Outcome.Result = VC.VC_Refuted then
                  Record_Definite_Error
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Proof.External_Prover,
                     "the loop variant does not make the declared bounded " &
                       "progress",
                     VC.Evidence);
               else
                  Record_VC_Unproved
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Proof.Abstract_Interpretation,
                     "loop-variant progress is not discharged",
                     "the bounded generic-iteration VC did not establish " &
                       "strict progress",
                     Item.Progress_Outcome);
               end if;
               return;
            end if;
         end loop;

         Final_Outcome
           (Expression, Proof.Loop_Variant_Check, Container,
            "loop-variant progress is not discharged");
      end Finalize_Loop_Variant;

      procedure Finalize_Node
        (Node      : Libadalang.Analysis.Ada_Node'Class;
         Container : CFG.Node_Id := CFG.No_Node);

      --  True for a construct nested in the subprogram being verified whose
      --  expressions or statements are not evaluated where it is declared.
      function Evaluated_Later
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is (Node.Kind in Libadalang.Common.Ada_Task_Body
            | Libadalang.Common.Ada_Entry_Body
            | Libadalang.Common.Ada_Subp_Decl
            | Libadalang.Common.Ada_Abstract_Subp_Decl
            | Libadalang.Common.Ada_Null_Subp_Decl
            | Libadalang.Common.Ada_Subp_Renaming_Decl
            | Libadalang.Common.Ada_Generic_Subp_Decl
            | Libadalang.Common.Ada_Generic_Package_Decl
            | Libadalang.Common.Ada_Entry_Decl
            | Libadalang.Common.Ada_Component_Decl
            | Libadalang.Common.Ada_Discriminant_Spec);

      --  The state the operand being finalized is checked in. Finalize_Operand
      --  and Finalize_Earlier replace it while they finalize one, and put
      --  it back afterwards.
      type Operand_View is record
         Guarded   : Boolean;
         Dead      : Boolean;
         Container : CFG.Node_Id;
         State     : Flow_State;
         Symbols   : VC.Symbolic_State;
      end record;

      function Current_Operand_View return Operand_View
      is ((Guarded   => Operand_Guarded,
           Dead      => Operand_Dead,
           Container => Operand_Container,
           State     => Operand_State,
           Symbols   => Operand_Symbols));

      procedure Restore (View : Operand_View) is
      begin
         Operand_Guarded := View.Guarded;
         Operand_Dead := View.Dead;
         Operand_Container := View.Container;
         Operand_State := View.State;
         Operand_Symbols := View.Symbols;
      end Restore;

      --  Finalizes Child, a child of the guarding expression Parent, in the
      --  state in which the evaluation of Parent reaches it.
      procedure Finalize_Operand
        (Parent    : Libadalang.Analysis.Ada_Node'Class;
         Child     : Libadalang.Analysis.Ada_Node'Class;
         Container : CFG.Node_Id)
      is
         Saved : constant Operand_View := Current_Operand_View;
      begin
         if not Boundary_Supported then
            --  No state is consulted: every obligation is unsupported.
            Finalize_Node (Child, Container);
            return;
         end if;

         declare
            State   : Flow_State := State_At (Container);
            Symbols : VC.Symbolic_State := Symbols_At (Container);
            Dead    : Boolean := Unreached (Container);
         begin
            Narrow_For_Operand (Parent, Child, State, Symbols, Dead);
            Operand_Guarded := True;
            Operand_Dead := Dead;
            Operand_Container := Container;
            Operand_State := State;
            Operand_Symbols := Symbols;
         end;
         Finalize_Node (Child, Container);
         Restore (Saved);
      exception
         when others =>
            Restore (Saved);
            raise;
      end Finalize_Operand;

      --  Finalizes the prefix of Attribute, an 'Old or a 'Loop_Entry, in
      --  the state it is evaluated in and not in the one of the place
      --  where it is written (FP-112). It is evaluated whether or not
      --  that place is reached.
      --
      --  The prefix of an 'Old of the postcondition is evaluated on entry.
      --  That of a 'Loop_Entry which names no loop is evaluated when the
      --  innermost loop is entered: the state of that loop's header holds
      --  every time the header is reached, the first time included. Any
      --  other such prefix is decided with no state.
      procedure Finalize_Earlier
        (Attribute : Libadalang.Analysis.Attribute_Ref)
      is
         Saved  : constant Operand_View := Current_Operand_View;
         Name   : constant String := Normalized_Text (Attribute.F_Attribute);
         Header : CFG.Node_Id := CFG.No_Node;
      begin
         if Name = "loop-entry"
           and then Fixpoint_Complete
           and then Attribute.F_Args.Children_Count = 0
           and then Attribute.Parent.Kind /= Libadalang.Common.Ada_Call_Expr
         then
            Header := Header_For (Enclosing_Loop (Attribute));
         end if;

         Operand_Guarded := True;
         Operand_Dead := False;
         Operand_Container := Header;
         if Header /= CFG.No_Node then
            Operand_Dead := not Reachable (Header);
            Operand_State := States (Header);
            Operand_Symbols := Symbolic_States (Header);
         elsif Entry_Known and then Name = "old" then
            Operand_State := Entry_Flow;
            Operand_Symbols := Entry_Flow_Symbols;
         else
            Operand_State := Empty_Flow_State;
            Operand_Symbols := VC.Empty_Symbolic_State;
         end if;
         Finalize_Node (Attribute.F_Prefix, Header);
         Restore (Saved);
      exception
         when others =>
            Restore (Saved);
            raise;
      end Finalize_Earlier;

      --  The verdict on the read Node of an object of which the converged
      --  state of its node says Initialized.
      procedure Record_Final_Initialization
        (Node        : Libadalang.Analysis.Ada_Node'Class;
         Initialized : Abstract_Bool) is
      begin
         case Initialized is
            when Bool_True =>
               --  proof-path: initialization-final
               Record_Proved_Safe
                 (Unit, Node, Proof.Initialization_Check,
                  Proof.Flow_Analysis,
                  "object is initialized on every incoming path",
                  "initialization => true", Final => True);
            when Bool_False =>
               Record_Definite_Error
                 (Unit, Node, Proof.Initialization_Check,
                  Proof.Flow_Analysis,
                  "object is uninitialized on every incoming path",
                  "initialization => false", Final => True);
            when Bool_Unknown =>
               Record_Unproved
                 (Unit, Node, Proof.Initialization_Check,
                  Proof.Flow_Analysis,
                  "object initialization is not established",
                  Imprecision =>
                    "incoming paths disagree or object is external",
                  Final => True);
         end case;
      end Record_Final_Initialization;

      procedure Finalize_Node
        (Node      : Libadalang.Analysis.Ada_Node'Class;
         Container : CFG.Node_Id := CFG.No_Node)
      is
         Here : CFG.Node_Id := Container;
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Evaluated_Earlier (Node) then
            Finalize_Earlier (Node.As_Attribute_Ref);
            return;
         end if;

         --  Code that is declared in this subprogram and evaluated later --
         --  the default of a component or of a nested subprogram's
         --  parameter, a task or entry body -- runs in a state this pass
         --  knows nothing about, not in the state at its declaration
         --  (FP-108): what an enclosing object held there says nothing
         --  about what it holds where the code runs. Its obligations are
         --  decided with no state at all. A nested subprogram body or
         --  expression function is verified on its own, from its own entry
         --  state, and is not walked here.
         if Libadalang.Analysis.Ada_Node (Node) /=
             Libadalang.Analysis.Ada_Node (Subprogram)
           and then Evaluated_Later (Node)
         then
            for Index in 1 .. Node.Children_Count loop
               Finalize_Node (Node.Child (Index), CFG.No_Node);
            end loop;
            return;
         end if;

         declare
            Match : constant CFG.Node_Id :=
              Matching_CFG_Node (Libadalang.Analysis.Ada_Node (Node));
         begin
            if Match /= CFG.No_Node then
               Here := Match;
            end if;
         end;

         --  Several branches below call Libadalang properties
         --  (P_Expression_Type, P_Designated_Type_Decl, ...) directly as
         --  argument expressions, outside any begin/exception block of
         --  their own. A Property_Error from one of those (e.g. the same
         --  precise-resolution failure documented for FP-040's CallExpr.P_
         --  Kind case, or the unrelated "dereferencing a null access"
         --  memoized failures seen on real corpora such as CubedOS) used to
         --  escape Finalize_Node entirely and abort the whole file via
         --  Process_File's outer handler, instead of just this one node's
         --  obligations. This outer handler makes every branch as
         --  conservative as the Ada_Call_Expr/Ada_Identifier branches
         --  already were: skip this node's own finalization and fall
         --  through to the child-recursion loop below so the rest of the
         --  file is still analyzed.
         begin
            if Node.Kind in Libadalang.Common.Ada_Bin_Op_Range then
               declare
                  Expr : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               begin
                  Finalize_Division_Check (Expr, Here);
                  Finalize_Overflow_Check (Expr, Here);
                  Finalize_Operator_Call (Expr.F_Op, Here);
                  Finalize_Array_Operator (Expr, Here);
               end;
            elsif Node.Kind = Libadalang.Common.Ada_Un_Op then
               Finalize_Operator_Call (Node.As_Un_Op.F_Op, Here);
            elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt
              and then Array_Dimensions
                         (Node.As_Assign_Stmt.F_Dest.P_Expression_Type) > 0
            then
               --  An array has a length to check, not a range.
               Finalize_Array_Assignment (Node.As_Assign_Stmt, Here);
            elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
               declare
                  Target : constant Target_Subtype :=
                    Stored_Subtype
                      (Node.As_Assign_Stmt.F_Dest, State_At (Here));
               begin
                  Finalize_Range_Check
                    (Node.As_Assign_Stmt.F_Expr, Target.Typ, Here,
                     Rules.Known_Range_Check_Failure,
                     "assigned value is outside the target subtype range",
                     Target.Constraint);
               end;
            elsif Node.Kind = Libadalang.Common.Ada_Object_Decl
              and then not Libadalang.Analysis.Is_Null
                (Node.As_Object_Decl.F_Default_Expr)
              and then Array_Dimensions
                         (Node.As_Object_Decl.F_Type_Expr
                            .P_Designated_Type_Decl) > 0
            then
               Finalize_Array_Given
                 (Node.As_Object_Decl.F_Type_Expr.P_Designated_Type_Decl,
                  Node.As_Object_Decl.F_Type_Expr,
                  Node.As_Object_Decl.F_Default_Expr, Here);
            elsif Node.Kind = Libadalang.Common.Ada_Object_Decl
              and then not Libadalang.Analysis.Is_Null
                (Node.As_Object_Decl.F_Default_Expr)
            then
               Finalize_Range_Check
                 (Node.As_Object_Decl.F_Default_Expr,
                  Node.As_Object_Decl.F_Type_Expr.P_Designated_Type_Decl, Here,
                  Rules.Known_Range_Check_Failure,
                  "initial value is outside the object's subtype range",
                  Declared_Constraint
                    (Node.As_Object_Decl.F_Type_Expr, State_At (Here)));
            elsif Node.Kind = Libadalang.Common.Ada_Return_Stmt
              and then not Libadalang.Analysis.Is_Null
                (Node.As_Return_Stmt.F_Return_Expr)
            then
               --  The value a function returns is given to its result
               --  subtype.
               Finalize_Array_Given
                 (Designated_Type (Subprogram.F_Subp_Spec.F_Subp_Returns),
                  Subprogram.F_Subp_Spec.F_Subp_Returns,
                  Node.As_Return_Stmt.F_Return_Expr, Here);
            elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
               declare
                  Call : constant Libadalang.Analysis.Call_Expr :=
                    Node.As_Call_Expr;
               begin
                  case Call.P_Kind is
                     when Libadalang.Common.Type_Conversion =>
                        declare
                           Decl  : constant Libadalang.Analysis.Basic_Decl :=
                             Call.F_Name.P_Referenced_Decl;
                           Value : constant Libadalang.Analysis.Expr :=
                             Assoc_Expression (Call.F_Suffix, 1);
                        begin
                           if not Libadalang.Analysis.Is_Null (Decl)
                             and then Decl.Kind in
                               Libadalang.Common.Ada_Base_Type_Decl
                             and then not Libadalang.Analysis.Is_Null (Value)
                           then
                              if Array_Dimensions (Decl.As_Base_Type_Decl) > 0
                              then
                                 --  A conversion to a constrained array
                                 --  subtype checks the length of its
                                 --  operand.
                                 Finalize_Array_Given
                                   (Decl.As_Base_Type_Decl,
                                    Libadalang.Analysis.No_Type_Expr, Value,
                                    Here);
                              else
                                 Finalize_Range_Check
                                   (Value, Decl.As_Base_Type_Decl, Here,
                                    Rules.Known_Range_Check_Failure,
                                    "value is outside the target subtype " &
                                      "range");
                              end if;
                           end if;
                        end;

                     when Libadalang.Common.Array_Index =>
                        declare
                           Array_Type : constant Libadalang.Analysis.Base_Type_Decl :=
                             Call.F_Name.P_Expression_Type;
                           Dimensions : constant Positive :=
                             (if Call.F_Suffix.Kind in Libadalang.Common.Ada_Expr
                              then 1 else Call.F_Suffix.Children_Count);
                           Here_State : constant Flow_State :=
                             State_At (Here);
                        begin
                           if not Libadalang.Analysis.Is_Null (Array_Type)
                             and then Array_Type.P_Is_Array_Type
                           then
                              for Dimension in 1 .. Dimensions loop
                                 declare
                                    Index_Value : constant
                                      Libadalang.Analysis.Expr :=
                                        Assoc_Expression
                                          (Call.F_Suffix, Dimension);
                                 begin
                                    if not Libadalang.Analysis.Is_Null
                                      (Index_Value)
                                    then
                                       if Indexed_Prefix_Is_Slice (Call) then
                                          Record_Unproved
                                            (Unit, Index_Value,
                                             Proof.Index_Check,
                                             Proof.Abstract_Interpretation,
                                             "index-check failure is not " &
                                               "established, but absence is " &
                                               "not proved",
                                             Imprecision =>
                                               "indexed prefix is an array " &
                                               "slice; slice bounds are not " &
                                               "modelled by the scalar domain",
                                             Final => True);
                                       else
                                          Finalize_Index_Check
                                            (Index_Value,
                                             Array_Object_Index_Range
                                               (Call.F_Name, Dimension,
                                                Here_State),
                                             Here, Call, Dimension);
                                       end if;
                                    end if;
                                 end;
                              end loop;
                           end if;
                        end;

                     when Libadalang.Common.Call =>
                        declare
                           Decl : constant Libadalang.Analysis.Basic_Decl :=
                             Call_Declaration (Call.F_Name);
                        begin
                           if not Libadalang.Analysis.Is_Null (Decl)
                             and then not Libadalang.Analysis.Is_Null
                               (Contract_Expression (Decl, "Pre"))
                           then
                              Finalize_Precondition_Check (Call, Here);
                           end if;
                        end;

                     when Libadalang.Common.Array_Slice =>
                        Finalize_Slice_Check (Call, Here);

                     when others =>
                        null;
                  end case;
               exception
                  when E : others =>
                     Report_Recoverable_Failure_Once
                       (Rule       => "Verification",
                        Operation  => "finalize expression proof obligations",
                        Source     => Ada_Text.Safe_Filename (Unit),
                        Occurrence => E);
               end;
            elsif Node.Kind = Libadalang.Common.Ada_Attribute_Ref then
               Finalize_Length_Check (Node.As_Attribute_Ref, Here);
            elsif Node.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
               Finalize_Array_Component (Node.As_Aggregate_Assoc, Here);
            elsif Node.Kind = Libadalang.Common.Ada_Pragma_Node then
               declare
                  Pragma_Node : constant Libadalang.Analysis.Pragma_Node :=
                    Node.As_Pragma_Node;
                  Name : constant String :=
                    Normalized_Text (Pragma_Node.F_Id);
                  Cond : constant Libadalang.Analysis.Expr :=
                    Verification_Pragma_Condition (Pragma_Node);
               begin
                  if not Libadalang.Analysis.Is_Null (Cond)
                    and then Name /= "assume"
                  then
                     if Name /= "loop-variant" then
                        Finalize_Assertion_Check (Cond, Here);
                     end if;
                     if Name = "loop-invariant" then
                        Finalize_Loop_Invariant (Cond, Here);
                     elsif Name = "loop-variant" then
                        Finalize_Loop_Variant (Cond, Here);
                     end if;
                  end if;
               end;
            elsif Node.Kind = Libadalang.Common.Ada_Identifier
              and then Initialization_Read_Required (Node)
            then
               declare
                  Key     : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Referenced_Name (Node);
                  Current : Libadalang.Analysis.Ada_Node := Key;
                  Tracked : Boolean := False;
               begin
                  while not Libadalang.Analysis.Is_Null (Current) loop
                     if Current.Kind in
                       Libadalang.Common.Ada_Object_Decl_Range
                         | Libadalang.Common.Ada_Param_Spec_Range
                     then
                        Tracked := True;
                        exit;
                     elsif Current.Kind in Libadalang.Common.Ada_Basic_Decl then
                        exit;
                     end if;
                     Current := Current.Parent;
                  end loop;
                  if Tracked then
                     if not Boundary_Supported then
                        Record_Unsupported
                          (Unit, Node, Proof.Initialization_Check,
                           "object initialization has not been established");
                     elsif Unreached (Here)
                     then
                        Record_Unreachable
                          (Unit, Node, Proof.Initialization_Check,
                           "the containing CFG node is unreachable");
                     else
                        --  Unlike the live recording this mirrors (made while
                        --  Verify_Subprogram's CFG fixed point may still be
                        --  mid-convergence for Here, and so can be based on an
                        --  intermediate, not-yet-joined state), this call is
                        --  made once, after the fixed point has fully
                        --  converged, against Here's own final State -- so it
                        --  is marked Final to always supersede whatever a
                        --  premature live recording left behind for the same
                        --  obligation (see FP-031).
                        declare
                           Standing : Boolean;
                        begin
                           Record_Standing_Value
                             (Unit, Node, Key, State_At (Here), True,
                              Standing);
                           if not Standing then
                              Record_Final_Initialization
                                (Node, Flow_Initialization
                                         (State_At (Here), Key));
                           end if;
                        end;
                     end if;
                     Proof.Set_Subject
                       (Unit, Node, Proof.Initialization_Check, Key);
                  end if;
               exception
                  when E : others =>
                     Report_Recoverable_Failure_Once
                       (Rule       => "Initialization_Check",
                        Operation  => "finalize identifier proof obligation",
                        Source     => Ada_Text.Safe_Filename (Unit),
                        Occurrence => E);
               end;
            end if;
         exception
            when E : others =>
               Report_Recoverable_Failure_Once
                 (Rule       => "Verification",
                  Operation  => "finalize node proof obligations",
                  Source     => Ada_Text.Safe_Filename (Unit),
                  Occurrence => E);
         end;

         --  Final obligation enumeration follows the same read/write
         --  distinction as the transfer scan above. In particular, an
         --  identifier used as an out-only actual does not itself create an
         --  initialization obligation.
         if Node.Kind = Libadalang.Common.Ada_Call_Expr then
            declare
               --  Node.As_Call_Expr.P_Kind can itself raise Property_Error
               --  (e.g. Libadalang's own "undetermined CallExpr kind" when
               --  precise overload resolution fails for a call into a
               --  separate, with'd GNAT project -- see FP-040). Unlike the
               --  case statement above, this second P_Kind call sits in an
               --  if-condition rather than inside a begin/exception block,
               --  so an unhandled failure here used to escape Finalize_Node
               --  entirely and abort the whole file via Process_File's
               --  outer handler instead of just this one obligation.
               Is_Plain_Call : Boolean := False;
            begin
               begin
                  Is_Plain_Call :=
                    Node.As_Call_Expr.P_Kind = Libadalang.Common.Call;
               exception
                  when others =>
                     Is_Plain_Call := False;
               end;

               if Is_Plain_Call then
                  Finalize_Actual_Checks (Node.As_Call_Expr, Here);
               end if;

               if Is_Plain_Call then
                  begin
                     Finalize_Node (Node.As_Call_Expr.F_Name, Here);
                     for Pair of Node.As_Call_Expr.F_Name.P_Call_Params loop
                        if Formal_Mode (Libadalang.Analysis.Param (Pair)) /=
                          Libadalang.Common.Ada_Mode_Out
                          or else Libadalang.Analysis.Actual (Pair).Kind /=
                            Libadalang.Common.Ada_Identifier
                        then
                           Finalize_Node
                             (Libadalang.Analysis.Actual (Pair), Here);
                        end if;
                     end loop;
                     return;
                  exception
                     when others =>
                        --  Fall through to conservative raw-tree
                        --  enumeration when semantic parameter resolution
                        --  is unavailable.
                        null;
                  end;
               end if;
            end;
         end if;

         --  An aspect specification (Global, Depends, ...) is never
         --  executed at its own textual position -- unlike Pre/Post, which
         --  are genuinely-evaluated expressions and are already scanned
         --  explicitly via Contract_Expression/Scan_Expression_For_Flow_Bugs
         --  above, an aspect like "Global => (In_Out => (X, Y))" merely
         --  names X and Y as a contract; it must not be walked as if it
         --  were a read, or every scalar named in a nested subprogram's
         --  Global aspect would appear to read the outer object before it
         --  is ever assigned.
         if Node.Kind = Libadalang.Common.Ada_Aspect_Spec then
            return;
         end if;

         for Index in 1 .. Node.Children_Count loop
            if Node.Kind not in Libadalang.Common.Ada_Subp_Body
                 | Libadalang.Common.Ada_Expr_Function
              or else Libadalang.Analysis.Ada_Node (Node) =
                Libadalang.Analysis.Ada_Node (Subprogram)
            then
               if Guards_Operands (Node) then
                  Finalize_Operand (Node, Node.Child (Index), Here);
               else
                  Finalize_Node (Node.Child (Index), Here);
               end if;
            end if;
         end loop;
      end Finalize_Node;

      --  The checks inside a contract of the subprogram are obligations
      --  too. Root is evaluated in State and Symbols, or never when Dead:
      --  the precondition on entry, before anything is known beyond the
      --  subtypes of the parameters, the postcondition at the normal exit.
      --  On entry State does not come from the body: what a precondition
      --  is evaluated in is known even where the body is outside the
      --  verified subset. A postcondition's checks are Unsupported there,
      --  like those of the body, and not missing; they are never evaluated
      --  when the normal exit is not reached.
      type Contract_Moment is (On_Entry, At_Exit);

      procedure Finalize_Contract
        (Root    : Libadalang.Analysis.Expr;
         State   : Flow_State;
         Symbols : VC.Symbolic_State;
         Moment  : Contract_Moment)
      is
         Supported : constant Boolean := Boundary_Supported;
         Dead      : constant Boolean :=
           Moment = At_Exit
           and then not Reachable (CFG.Normal_Exit (Graph));

         procedure Clear is
         begin
            Operand_Guarded := False;
            Operand_Dead := False;
            Operand_Container := CFG.No_Node;
            Boundary_Supported := Supported;
         end Clear;
      begin
         if Libadalang.Analysis.Is_Null (Root) then
            return;
         end if;

         if Moment = On_Entry then
            Boundary_Supported := True;
         end if;
         Operand_Guarded := True;
         Operand_Dead := Dead;
         Operand_Container := CFG.No_Node;
         Operand_State := State;
         Operand_Symbols := Symbols;
         Finalize_Node (Root, CFG.No_Node);
         Clear;
      exception
         when E : others =>
            Clear;
            Report_Recoverable_Failure_Once
              (Rule       => "Verification",
               Operation  => "finalize contract proof obligations",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Finalize_Contract;

      Initial : Flow_State := Empty_Flow_State;
      Initial_Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      --  Initial before the precondition is assumed.
      Entry_State : Flow_State := Empty_Flow_State;
      Pairs   : constant Parameter_Pair_Vectors.Vector := Parameter_Pairs;
      Pre     : constant Libadalang.Analysis.Expr :=
        Contract_Expression (Subprogram, "Pre");
      Post    : constant Libadalang.Analysis.Expr :=
        Contract_Expression (Subprogram, "Post");
   begin
      --  Read by Report_Flow_Violation throughout the run.
      Fixpoint_In_Progress := True;  --  adalang-analyzer: ignore Overwritten_Assignment
      Collect_Loop_Invariants (Subprogram);
      Collect_Effectful_Calls;
      Seed_Parameters (Initial);
      for Pair of Pairs loop
         Flow_Copy_Key (Initial, Pair.Body_Name, Pair.Spec_Name);
      end loop;
      Entry_State := Initial;
      if not Libadalang.Analysis.Is_Null (Pre) then
         declare
            True_State, False_State : Flow_State;
         begin
            Scan_Expression_For_Flow_Bugs (Unit, Pre, Initial);
            Narrow_By_Condition (Pre, Initial, True_State, False_State);
            Initial := True_State;
            Initial_Symbols :=
              Assume_Condition
                (VC.Empty_Symbolic_State, Pre, Truth => True,
                 Flow => Initial);
            for Pair of Pairs loop
               Flow_Copy_Key (Initial, Pair.Spec_Name, Pair.Body_Name);
               Initial_Symbols :=
                 VC.Alias_Object
                   (Initial_Symbols, Pair.Spec_Name, Pair.Body_Name);
            end loop;
         end;
      end if;

      for Edge_Index in 1 .. CFG.Edge_Count (Graph) loop
         declare
            To : constant CFG.Node_Id := CFG.Edge_At (Graph, Edge_Index).To;
         begin
            if To in In_Degree'Range then
               In_Degree (To) := In_Degree (To) + 1;
            end if;
         end;
      end loop;

      Reachable (CFG.Entry_Id (Graph)) := True;
      States (CFG.Entry_Id (Graph)) := Initial;
      Symbolic_States (CFG.Entry_Id (Graph)) := Initial_Symbols;
      Enqueue (CFG.Entry_Id (Graph));

      if Boundary_Supported then
         while Head <= Natural (Work.Length) loop
            declare
               Id : constant CFG.Node_Id := Work.Element (Head);
            begin
               Head := Head + 1;
               Process_Node (Id);
            end;
         end loop;

         Prove_Loop_Preservation_VCs;

         --  Once induction has been checked independently, rerun the CFG
         --  with each proved loop represented by its invariant summary.
         --  Back edges into such a summary are cut: the invariant denotes
         --  an arbitrary iteration, so iterating concrete symbolic terms
         --  would only destroy the relational fact at downstream joins.
         Summary_Mode := True;  --  adalang-analyzer: ignore Dead_Store -- rationale: read by nested Process_Node
         States := (others => Empty_Flow_State);
         Symbolic_States := (others => VC.Empty_Symbolic_State);
         Reachable := (others => False);
         Updates := (others => 0);  --  adalang-analyzer: ignore Dead_Store -- rationale: read by nested Process_Node
         Work.Clear;
         Head := 1;
         Reachable (CFG.Entry_Id (Graph)) := True;
         States (CFG.Entry_Id (Graph)) := Initial;
         Symbolic_States (CFG.Entry_Id (Graph)) := Initial_Symbols;
         Enqueue (CFG.Entry_Id (Graph));

         while Head <= Natural (Work.Length) loop
            declare
               Id : constant CFG.Node_Id := Work.Element (Head);
            begin
               Head := Head + 1;
               Process_Node (Id);
            end;
         end loop;
      end if;

      Fixpoint_Complete := True;
      Fixpoint_In_Progress := False;

      --  A condition is constant only if it is so in the state every path
      --  to it agrees on.
      for Id in States'Range loop
         if Reachable (Id)
           and then CFG.Node_At (Graph, Id).Kind in
             CFG.Condition_Node | CFG.Loop_Header_Node
         then
            Check_Flow_Condition
              (Unit, Boolean_Condition (Source_Node (Id)), States (Id));
         end if;
      end loop;
      Finalize_Node (Subprogram);
      Finalize_Output_Parameters;
      Finalize_Output_Globals;
      Finalize_Contract
        (Pre, Entry_State, VC.Empty_Symbolic_State, On_Entry);
      declare
         --  A spec postcondition names the spec's parameters: give them
         --  the body parameters' exit facts (FP-085).
         Exit_State   : Flow_State := States (CFG.Normal_Exit (Graph));
         Exit_Symbols : VC.Symbolic_State :=
           Symbolic_States (CFG.Normal_Exit (Graph));
      begin
         for Pair of Pairs loop
            Flow_Copy_Key (Exit_State, Pair.Body_Name, Pair.Spec_Name);
            Exit_Symbols :=
              VC.Alias_Object (Exit_Symbols, Pair.Body_Name, Pair.Spec_Name);
         end loop;
         Entry_Known := True;
         Entry_Flow := Initial;
         Entry_Flow_Symbols := Initial_Symbols;
         Finalize_Contract (Post, Exit_State, Exit_Symbols, At_Exit);
         Entry_Known := False;
      end;

      if not Libadalang.Analysis.Is_Null (Post) then
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Post, Proof.Postcondition_Check,
               "subprogram is outside the bounded verification subset");
         elsif not Reachable (CFG.Normal_Exit (Graph)) then
            Record_Unreachable
              (Unit, Post, Proof.Postcondition_Check,
               "the subprogram has no reachable normal exit");
         else
            declare
               --  A spec postcondition names the spec's parameters: give
               --  them the body parameters' exit facts (FP-085).
               function Exit_Flow return Flow_State is
                  Result : Flow_State := States (CFG.Normal_Exit (Graph));
               begin
                  for Pair of Pairs loop
                     Flow_Copy_Key (Result, Pair.Body_Name, Pair.Spec_Name);
                  end loop;
                  return Result;
               end Exit_Flow;

               function Exit_Symbols return VC.Symbolic_State is
                  Result : VC.Symbolic_State :=
                    Symbolic_States (CFG.Normal_Exit (Graph));
               begin
                  for Pair of Pairs loop
                     Result :=
                       VC.Alias_Object
                         (Result, Pair.Body_Name, Pair.Spec_Name);
                  end loop;
                  return Result;
               end Exit_Symbols;

               Exit_State : constant Flow_State := Exit_Flow;
               Value : constant Abstract_Bool :=
                 Boolean_Value (Post, Exit_State);
               VC_Outcome : constant VC.VC_Outcome :=
                 (if Value = Bool_Unknown
                  then VC.Decide (Post, Exit_State, Exit_Symbols)
                  else VC.Unknown_Outcome);
               VC_Result : constant VC.VC_Result := VC_Outcome.Result;
            begin
               Scan_Expression_For_Flow_Bugs (Unit, Post, Exit_State);
               if Value = Bool_True or else VC_Result = VC.VC_Proved then
                  --  proof-path: postcondition-final
                  Record_Proved_Safe
                    (Unit, Post, Proof.Postcondition_Check,
                     (if VC_Result = VC.VC_Proved
                      then Proof.External_Prover
                      else Proof.Abstract_Interpretation),
                     "every represented normal exit satisfies the " &
                       "postcondition",
                     (if VC_Result = VC.VC_Proved
                      then VC.Evidence else "postcondition => true"));
               elsif Value = Bool_False
                 or else
                   (VC_Result = VC.VC_Refuted
                    and then not Contains_VC_Arithmetic (Post))
               then
                  Record_Definite_Error
                    (Unit, Post, Proof.Postcondition_Check,
                     (if VC_Result = VC.VC_Refuted
                      then Proof.External_Prover
                      else Proof.Abstract_Interpretation),
                     "every represented normal exit violates the " &
                       "postcondition",
                     (if VC_Result = VC.VC_Refuted
                      then VC.Evidence else "postcondition => false"));
               else
                  Record_VC_Unproved
                    (Unit, Post, Proof.Postcondition_Check,
                     Proof.Abstract_Interpretation,
                     "postcondition is inconclusive at the joined normal " &
                       "exit",
                     "exit states do not imply the contract",
                     VC_Outcome);
               end if;
            end;
         end if;
      end if;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("bounded verification skipped for subprogram: " &
            Ada.Exceptions.Exception_Message (Exc));
         if not Fixpoint_Complete then
            Boundary_Supported := False;
         end if;
         Fixpoint_In_Progress := False;
         Finalize_Node (Subprogram);
         if not Boundary_Supported then
            --  No state is consulted: every obligation is unsupported.
            Finalize_Node (Contract_Expression (Subprogram, "Pre"));
            Finalize_Node (Contract_Expression (Subprogram, "Post"));
         end if;
   end Verify_Subprogram;

   procedure Verify_Unit
     (Unit : Libadalang.Analysis.Analysis_Unit)
   is
      procedure Visit (Node : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind in Libadalang.Common.Ada_Subp_Body
                 | Libadalang.Common.Ada_Expr_Function
         then
            Verify_Subprogram (Unit, Node.As_Base_Subp_Body);
         end if;

         for Index in 1 .. Node.Children_Count loop
            Visit (Node.Child (Index));
         end loop;
      end Visit;

      --  A component selected from an object whose own static
      --  discriminant constraint selects that component's variant can never
      --  fail its discriminant check: a constrained object's discriminants
      --  are fixed for its lifetime. Runs before Visit so an Unreachable
      --  result from the subprogram pass still takes precedence.
      procedure Visit_Discriminant_Accesses
        (Node : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Dotted_Name
           and then SPARK_Readiness.Discriminant_Access_Proved
             (Node.As_Dotted_Name)
         then
            --  proof-path: discriminant-static-constraint
            Record_Proved_Safe
              (Unit, Node, Proof.Discriminant_Check,
               Proof.Static_Evaluation,
               "the object's discriminant constraint selects the "
               & "component's variant",
               "selected variant declares the referenced component");
         end if;

         for Index in 1 .. Node.Children_Count loop
            Visit_Discriminant_Accesses (Node.Child (Index));
         end loop;
      end Visit_Discriminant_Accesses;
   begin
      if Config.Verification_Mode then
         if Config.Rule_States (Rules.Known_Discriminant_Check_Failure) =
           Config.Enabled
         then
            Visit_Discriminant_Accesses (Unit.Root);
         end if;
         for Effects of Body_Effects loop
            Effects.Clear;
         end loop;
         Functions_Of_Arguments.Clear;
         Visit (Unit.Root);
      end if;
   end Verify_Unit;

begin
   VC.Set_Function_Oracle (Is_Function_Of_Arguments'Access);
end Adalang_Analyzer.Flow_Interp;
