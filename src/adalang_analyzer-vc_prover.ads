--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Libadalang.Analysis;

with Adalang_Analyzer.Flow_Domain;

--  A deliberately small external-prover bridge. It translates a side-effect
--  free scalar Boolean expression plus the current abstract flow constraints
--  to SMT-LIB. Proved/Refuted are returned only when both CVC5 and Z3 report
--  UNSAT for the corresponding negated/direct query.
package Adalang_Analyzer.VC_Prover is

   type VC_Result is
     (VC_Proved,
      VC_Refuted,
      VC_Unknown,
      VC_Unsupported,
      VC_Unavailable);

   type Symbolic_State is private;
   Empty_Symbolic_State : constant Symbolic_State;

   function Assign
      (State       : Symbolic_State;
      Destination : Libadalang.Analysis.Ada_Node;
      Value       : Libadalang.Analysis.Expr'Class;
      Flow        : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;

   function Assume
     (State     : Symbolic_State;
      Condition : Libadalang.Analysis.Expr;
      Truth     : Boolean;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;

   function Join
     (Left, Right : Symbolic_State;
      Flow        : Adalang_Analyzer.Flow_Domain.Flow_State;
      Merge_Tag   : Positive) return Symbolic_State;

   function Equal (Left, Right : Symbolic_State) return Boolean;

   function Havoc return Symbolic_State is (Empty_Symbolic_State);

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Adalang_Analyzer.Flow_Domain.Flow_State) return VC_Result;

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols   : Symbolic_State) return VC_Result;

   function Decide_Bounds
     (Value   : Libadalang.Analysis.Expr'Class;
      Bounds  : Adalang_Analyzer.Flow_Domain.Abstract_Range;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Result;
   --  As Decide, but for a containment goal (Bounds.Low <= Value and/or
   --  Value <= Bounds.High, whichever side Bounds supplies) synthesized
   --  from Value's own translated term instead of a literal source
   --  condition. This is the query shape a range, index, or overflow check
   --  needs: none of them have a source Expr spelling out their own
   --  in-bounds condition the way an Assert or Loop_Invariant does.
   --  VC_Unsupported when Bounds carries neither side.

   function Decide_Nonzero
     (Value   : Libadalang.Analysis.Expr'Class;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Result;
   --  As Decide_Bounds, for Division_By_Zero_Check's "divisor /= 0" goal,
   --  which Abstract_Range cannot express (a single excluded point, not a
   --  bound).

   procedure Dump_Symbolic_Diagnostics;
   --  Phase 0 v2 measurement scaffolding (diagnostic only): when
   --  ADALANG_VERIFY_SYMBOLIC_DIAGNOSTICS is set, prints tallies of why
   --  Assign/Assume/Join/Include_Root discarded symbolic facts during this
   --  run, to stderr. A no-op otherwise. Intended to be called once, after
   --  a full analysis run, to identify which discard mechanism dominates
   --  before any of them is redesigned -- see
   --  quality/external_corpus_findings.md's "Relational fallback for
   --  --verify" section for why this question matters.

   function Evidence return String;

private

   type Scalar_Sort is (Integer_Sort, Boolean_Sort, Enum_Sort);
   --  Enum_Sort values are represented in SMT-LIB by their 0-based
   --  declaration-order position (matching Ada's 'Pos, not GNAT's Enum_Rep,
   --  which a representation clause can remap) -- see Enum_Literal_Position
   --  and Enum_Type_Position_Range in the body. Scoped to equality and
   --  membership-test translation only: no ordering, 'Succ/'Pred, or
   --  'Pos/'Val attribute support yet.

   --  Identifies what a root/binding stands for: an ordinary object
   --  (Component = No_Ada_Node), or one record component of one object
   --  (Object.Component, e.g. "TheAdmin.RolePresent") -- Component alone
   --  is shared by every object of the record type (it is the component's
   --  own declaration inside the type, not a per-object identity), so
   --  Object is what actually distinguishes one object's field from
   --  another's. Ordinary record-equality comparison (both fields'
   --  Ada_Node "=") is exactly the identity check every use site needs.
   type Symbol_Key is record
      Object    : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Component : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
   end record;

   type Symbol_Root is record
      Name       : Ada.Strings.Unbounded.Unbounded_String;
      Key        : Symbol_Key;
      Sort       : Scalar_Sort := Integer_Sort;
      Has_Low    : Boolean := False;
      Low        : Long_Long_Integer := 0;
      Has_High   : Boolean := False;
      High       : Long_Long_Integer := 0;
   end record;

   package Symbol_Root_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Symbol_Root);

   type Symbolic_Binding is record
      Key  : Symbol_Key;
      Sort : Scalar_Sort := Integer_Sort;
      Term : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Symbolic_Binding_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Symbolic_Binding);

   package Assumption_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive,
      Element_Type => Ada.Strings.Unbounded.Unbounded_String,
      "=" => Ada.Strings.Unbounded."=");

   type Symbolic_State is record
      Roots       : Symbol_Root_Vectors.Vector;
      Bindings    : Symbolic_Binding_Vectors.Vector;
      Assumptions : Assumption_Vectors.Vector;
      Supported   : Boolean := True;
   end record;

   Empty_Symbolic_State : constant Symbolic_State :=
     (Roots       => Symbol_Root_Vectors.Empty_Vector,
      Bindings    => Symbolic_Binding_Vectors.Empty_Vector,
      Assumptions => Assumption_Vectors.Empty_Vector,
      Supported   => True);

end Adalang_Analyzer.VC_Prover;
