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

   type Unsupported_Reason is
     (No_Unsupported_Reason,
      Null_Expression,
      Uninitialized_Object,
      Sort_Mismatch,
      Unsupported_Expression_Kind,
      Unsupported_Operator,
      Unsupported_Call,
      Unsupported_Conversion,
      Unsupported_Attribute,
      Unsupported_Quantifier,
      Missing_Static_Bounds,
      Unsafe_Divisor_Semantics,
      Inline_Depth_Exceeded,
      Callee_Not_Expression_Function,
      Writable_Formal,
      Record_Actual_Not_Object,
      Branch_Budget_Exceeded,
      Translation_Error);

   type Unsupported_Provenance is record
      Reason              : Unsupported_Reason := No_Unsupported_Reason;
      Blocking_Expression : Ada.Strings.Unbounded.Unbounded_String;
      Inline_Path         : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   No_Unsupported_Provenance : constant Unsupported_Provenance :=
     (Reason              => No_Unsupported_Reason,
      Blocking_Expression => Ada.Strings.Unbounded.Null_Unbounded_String,
      Inline_Path         => Ada.Strings.Unbounded.Null_Unbounded_String);

   type VC_Outcome is record
      Result     : VC_Result := VC_Unknown;
      Provenance : Unsupported_Provenance := No_Unsupported_Provenance;
   end record;

   Unknown_Outcome : constant VC_Outcome :=
     (Result => VC_Unknown, Provenance => No_Unsupported_Provenance);

   function Unsupported_Reason_Code (Outcome : VC_Outcome) return String;
   function Unsupported_Description (Outcome : VC_Outcome) return String;
   function Blocking_Expression (Outcome : VC_Outcome) return String;
   function Inline_Path (Outcome : VC_Outcome) return String;
   --  Provenance belongs to the returned decision, so nested or subsequent
   --  solver calls cannot overwrite it. Empty strings mean that Outcome is
   --  not VC_Unsupported or no more specific provenance was available.

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

   function Assume_Predicate
     (State     : Symbolic_State;
      Object    : Libadalang.Analysis.Ada_Node'Class;
      Predicate : Libadalang.Analysis.Expr;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State with Predicate assumed of a record object: the one whose
   --  defining name Object is, or the one, or the part of one, that Object
   --  names. Predicate is the predicate aspect of a type or subtype
   --  declaration, written in terms of the current instance. It is taken
   --  part by part, as Assume takes a condition. State as it is where the
   --  object is not initialized in Flow or nothing could be taken. It is
   --  for the caller to say this only where the predicate holds.

   function Join
     (Left, Right : Symbolic_State;
      Flow        : Adalang_Analyzer.Flow_Domain.Flow_State;
      Merge_Tag   : Positive;
      Rename      : Boolean := False) return Symbolic_State;
   --  What both states know. With Rename, also a fact both state alike of
   --  the values of the keys they disagree on, each named as the join
   --  names the key's value; not where the state is the head of a loop,
   --  whose own names a loop body's state also holds.

   function Join_On_Condition
     (True_Side, False_Side : Symbolic_State;
      Pre_Fork_Side          : Symbolic_State;
      Condition              : Libadalang.Analysis.Ada_Node'Class;
      Flow                   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Merge_Tag              : Positive) return Symbolic_State;

   --  As Join_On_Condition, but for a case-statement alternative: the ite
   --  selector is a range-membership predicate ("Selector is within
   --  Bounds") over the case's own selector expression, rather than a
   --  boolean condition -- the counterpart Advance's case-alternative
   --  right-fold uses in place of Join_On_Condition's if/elsif fork.
   function Join_On_Range
     (True_Side, False_Side : Symbolic_State;
      Pre_Fork_Side          : Symbolic_State;
      Selector                : Libadalang.Analysis.Expr'Class;
      Bounds                  : Adalang_Analyzer.Flow_Domain.Abstract_Range;
      Flow                    : Adalang_Analyzer.Flow_Domain.Flow_State;
      Merge_Tag               : Positive) return Symbolic_State;

   function Equal (Left, Right : Symbolic_State) return Boolean;

   --  The contract of a callee speaks of the callee's formals. A frame says
   --  what each formal stands for at one call, so that a condition of the
   --  contract can be assumed about the caller's own objects: no fact
   --  about a formal as such is ever left in a state. A formal the frame
   --  blocks stands for nothing, and an operand that names it is not
   --  assumed.
   type Contract_Frame is private;
   Empty_Contract_Frame : constant Contract_Frame;

   procedure Block_Formal
     (Frame  : in out Contract_Frame;
      Formal : Libadalang.Analysis.Ada_Node);

   procedure Bind_Formal
     (Frame  : in out Contract_Frame;
      State  : in out Symbolic_State;
      Formal : Libadalang.Analysis.Ada_Node;
      Actual : Libadalang.Analysis.Expr'Class;
      Flow   : Adalang_Analyzer.Flow_Domain.Flow_State);
   --  Formal stands for the value Actual has in State: its term when the
   --  formal is a scalar, the object it names otherwise, or the component
   --  of a record object, and so on inwards. Blocked when Actual has
   --  neither. It is for the caller to bind a formal only where
   --  the value of Actual in State is the value the formal has where the
   --  condition is evaluated.

   function Assume_In_Frame
     (State     : Symbolic_State;
      Frame     : Contract_Frame;
      Condition : Libadalang.Analysis.Expr;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  As Assume, Truth being True, for a condition written in terms of the
   --  formals Frame speaks of. Havoc when nothing of it could be assumed.

   procedure Bind_Record
     (Frame  : in out Contract_Frame;
      Formal : Libadalang.Analysis.Ada_Node;
      Actual : Libadalang.Analysis.Expr'Class;
      State  : Symbolic_State;
      Flow   : Adalang_Analyzer.Flow_Domain.Flow_State);
   --  Formal, a parameter of a record type, stands for the object Actual
   --  names, or for the part of one that the name settles, where that
   --  object is initialized in Flow: a component read through Formal is
   --  then the component of that object, known or not when the call is
   --  made. Frame is left as it is for any other formal or actual. It is
   --  for the caller to bind a formal only where the condition is evaluated
   --  with Actual holding the value it has in State.

   --  A call the translation cannot look into is still a term when it is
   --  to a function of its arguments: one with no side effect whose result
   --  depends on nothing but the values it is given. Two such calls with
   --  the same arguments have the same result, which is all the term says:
   --  "Has_Buffer (Ctx)" known on entry proves the "Has_Buffer (Ctx)" a
   --  callee requires, as long as Ctx has not changed in between. An
   --  argument that is not a scalar is the value of a whole object, a
   --  component of one, or the result of another such call.
   --
   --  Which functions those are is for the caller of this package to say.
   --  Without an oracle no call is taken that way.
   type Function_Oracle is access function
     (Call : Libadalang.Analysis.Name'Class) return Boolean;

   procedure Set_Function_Oracle (Oracle : Function_Oracle);

   procedure Assume_Component_Subtypes (Enabled : Boolean);
   --  From here on a symbol for a scalar component of a record object is,
   --  or is not, within the subtype the component is declared with. It is
   --  in SPARK code, where an object that is read is initialized in all
   --  its parts and holds no invalid value; elsewhere only what the state
   --  holds is known of a component.

   function Forget_Composite_Values
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class) return Symbolic_State;
   --  State after Writer has changed some object that is not a scalar, no
   --  matter which: an array element assigned, a call that may write
   --  through an access value. Every such object now holds a value of its
   --  own, about which nothing is known; what State says of scalars and of
   --  array bounds stands.

   function Forget_Unowned_Values
     (State      : Symbolic_State;
      Writer     : Libadalang.Analysis.Ada_Node'Class;
      Scope      : Libadalang.Analysis.Ada_Node;
      After      : Adalang_Analyzer.Flow_Domain.Flow_State;
      Keep_Parts : Boolean := False)
      return Symbolic_State;
   --  State after Writer, a call whose effects on objects by name are
   --  known to stay outside Scope, the subprogram being verified. What
   --  State says of a scalar object declared in Scope stands: such an
   --  object changes only when it is named, and Forget_Object is for the
   --  ones the call names. Everything else gets a value of its own:
   --  every object declared outside Scope, every record component, and
   --  every value that is not a scalar, whatever object it belongs to --
   --  a call may write through an access value. After is the flow state
   --  once Writer is done. With Keep_Parts, what State says of every part
   --  of an object declared in Scope, or of a parameter of Scope, stands
   --  too: for code where no access value can designate such an object,
   --  nor any part of it, and where a parameter is never the object the
   --  call writes by another name (SPARK code that takes no 'Access or
   --  'Address of anything).

   function Forget_Object
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class;
      Object : Libadalang.Analysis.Ada_Node;
      After  : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State after Writer has given the scalar Object a value of which
   --  nothing is known but what After says.

   function Assign_Component
     (State       : Symbolic_State;
      Destination : Libadalang.Analysis.Name'Class;
      Value       : Libadalang.Analysis.Expr'Class;
      Writer      : Libadalang.Analysis.Ada_Node'Class;
      Flow        : Adalang_Analyzer.Flow_Domain.Flow_State;
      Shared      : Boolean)
      return Symbolic_State;
   --  State after Writer has assigned Value to Destination, a component of
   --  a tracked object that the name settles ("Ctx.P.Next := 1"; no
   --  dereference, no index whose value is not known), declared as an
   --  object or a parameter, Flow being the state before: the part written
   --  and every part that shares storage with it gets a value of its own,
   --  the component the value's term when it is a scalar, and what State
   --  says of the other parts of the object stands. Shared when another
   --  name may denote the object -- two parameters passed by reference, a
   --  parameter and a global, outside SPARK code: then every part of every
   --  other object gets a value of its own too. Havoc for any other
   --  destination.

   function Settled_Object
     (Part : Libadalang.Analysis.Ada_Node'Class;
      Flow : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Libadalang.Analysis.Ada_Node;
   --  The object of which Part is a settled part (Assign_Component); null
   --  when it is none.

   function With_Flow_Ranges
     (State : Symbolic_State;
      Flow  : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State, where it speaks of the value of a scalar object that Flow
   --  bounds, saying that the value is within those bounds. For a state
   --  kept past a condition it took nothing from: what the interval domain
   --  learned from the condition is not lost.

   function Is_Settled_Part
     (Part : Libadalang.Analysis.Ada_Node'Class;
      Flow : Adalang_Analyzer.Flow_Domain.Flow_State) return Boolean;
   --  True when Part names a part of a tracked object that the name
   --  settles, as Assign_Component asks of its destination.

   function Forget_Part
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class;
      Part   : Libadalang.Analysis.Ada_Node'Class;
      After  : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State after Writer has given Part, a settled part (Is_Settled_Part),
   --  a value of which nothing is known: as Assign_Component, with no
   --  term for the part. Havoc when Part is not settled.

   function Bind_Actual
     (State  : Symbolic_State;
      Formal : Libadalang.Analysis.Ada_Node;
      Actual : Libadalang.Analysis.Expr'Class;
      Flow   : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  As Assign, for giving a callee's formal the value of its actual
   --  where the callee's contract is evaluated. An actual that is not a
   --  scalar leaves the rest of State as it is, which Assign does not;
   --  only when State already speaks of Formal, on a recursive call, is
   --  everything dropped.

   function Havoc return Symbolic_State is (Empty_Symbolic_State);

   function Alias_Object
     (State    : Symbolic_State;
      From, To : Libadalang.Analysis.Ada_Node) return Symbolic_State;
   --  Binds every symbol key of object To (itself and its record
   --  components) to the current term of the matching key of From, so both
   --  names denote one value. Only sound when From and To denote the same
   --  object, such as a parameter's spec and body defining names.

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Adalang_Analyzer.Flow_Domain.Flow_State) return VC_Outcome;

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols   : Symbolic_State) return VC_Outcome;

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols   : Symbolic_State;
      Frame     : Contract_Frame) return VC_Outcome;
   --  As Decide, for a condition written in terms of formals: each record
   --  formal Frame binds (Bind_Record) is read as the object it stands for.
   --  What Frame says of scalars is not used: those have their terms in
   --  Symbols.

   function Decide_Bounds
     (Value   : Libadalang.Analysis.Expr'Class;
      Bounds  : Adalang_Analyzer.Flow_Domain.Abstract_Range;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome;
   --  As Decide, but for a containment goal (Bounds.Low <= Value and/or
   --  Value <= Bounds.High, whichever side Bounds supplies) synthesized
   --  from Value's own translated term instead of a literal source
   --  condition. This is the query shape a range, index, or overflow check
   --  needs: none of them have a source Expr spelling out their own
   --  in-bounds condition the way an Assert or Loop_Invariant does.
   --  VC_Unsupported when Bounds carries neither side.

   function Decide_Index_In_Object
     (Index     : Libadalang.Analysis.Expr'Class;
      Prefix    : Libadalang.Analysis.Name'Class;
      State     : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols   : Symbolic_State;
      Dimension : Positive := 1) return VC_Outcome;
   --  Decides "Prefix'First (Dimension) <= Index and Index <= Prefix'Last
   --  (Dimension)" for the array object Prefix names, with the object's
   --  bounds as symbols where no declaration fixes them. This is the index
   --  check for an object whose bounds are not known as numbers: an
   --  unconstrained formal, most often.

   function Decide_Same_Length
     (Target     : Libadalang.Analysis.Expr'Class;
      Value      : Libadalang.Analysis.Expr'Class;
      Dimensions : Positive;
      State      : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols    : Symbolic_State) return VC_Outcome;
   --  Decides that the arrays Target and Value denote have the same length
   --  in each of their Dimensions: the length check of an array
   --  assignment. The length of an object or a component is the term of
   --  its 'Length, a number where a declaration fixes its bounds and a
   --  symbol otherwise; that of a slice written with its two bounds is
   --  worked out from them, and Target may be such a range alone, the one
   --  that constrains what the value is given to. VC_Unsupported for any
   --  other form.

   function Decide_Length
     (Value   : Libadalang.Analysis.Expr'Class;
      Length  : Long_Long_Integer;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome;
   --  As Decide_Same_Length, for a one-dimensional Value given to a
   --  subtype whose length is the number Length.

   function Array_Bound_Facts (State : Symbolic_State) return Symbolic_State;
   --  What State knows about the bounds and lengths of array objects, and
   --  nothing else. Those never change while the objects are visible, so
   --  such facts survive where every fact about a variable must be
   --  dropped, at the entry of a loop body in particular.

   function Assume_Loop_Range
     (State     : Symbolic_State;
      Parameter : Libadalang.Analysis.Ada_Node;
      Iteration : Libadalang.Analysis.Ada_Node'Class;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State with the fact that the loop parameter whose defining name is
   --  Parameter lies within Iteration, the loop's own "A'Range" or
   --  "Low .. High". Only bounds whose value cannot change during the loop
   --  are used; otherwise State is returned as it is.

   function Decide_Nonzero
     (Value   : Libadalang.Analysis.Expr'Class;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome;
   --  As Decide_Bounds, for Division_By_Zero_Check's "divisor /= 0" goal,
   --  which Abstract_Range cannot express (a single excluded point, not a
   --  bound).

   type Loop_Variant_Direction is (Decreases, Increases);

   function Decide_Variant_Progress
     (Value          : Libadalang.Analysis.Expr'Class;
      Direction      : Loop_Variant_Direction;
      Bounds         : Adalang_Analyzer.Flow_Domain.Abstract_Range;
      Before_State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Before_Symbols : Symbolic_State;
      After_State    : Adalang_Analyzer.Flow_Domain.Flow_State;
      After_Symbols  : Symbolic_State) return VC_Outcome;
   --  Proves a single loop-variant component across one generic iteration.
   --  Both evaluations must fit Bounds. A decreasing variant must be
   --  nonnegative before the iteration and strictly decrease; an increasing
   --  variant must strictly increase. Bounds make the mathematical-integer
   --  translation conservative with respect to Ada overflow.

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

   type Scalar_Sort is (Integer_Sort, Boolean_Sort, Enum_Sort, Opaque_Sort);
   --  Enum_Sort values are represented in SMT-LIB by their 0-based
   --  declaration-order position (matching Ada's 'Pos, not GNAT's Enum_Rep,
   --  which a representation clause can remap) -- see Enum_Literal_Position
   --  and Enum_Type_Position_Range in the body. Scoped to equality and
   --  membership-test translation only: no ordering, 'Succ/'Pred, or
   --  'Pos/'Val attribute support yet.
   --
   --  Opaque_Sort is the value of an object that is not a scalar: a token
   --  with no structure, the same for as long as the object is unchanged
   --  and good only as an argument of a function term.

   --  Identifies what a root/binding stands for: an ordinary object
   --  (Component = No_Ada_Node), or one record component of one object
   --  (Object.Component, e.g. "TheAdmin.RolePresent") -- Component alone
   --  is shared by every object of the record type (it is the component's
   --  own declaration inside the type, not a per-object identity), so
   --  Object is what actually distinguishes one object's field from
   --  another's. Ordinary record-equality comparison (both fields'
   --  Ada_Node "=") is exactly the identity check every use site needs.
   --
   --  Path is the way from Object to the record the component is read in,
   --  where that is not Object itself: ".inner" for a component that is a
   --  record, "@3" for the element of an array at an index whose value is
   --  known -- the position, for an enumeration -- and any sequence of the
   --  two (".cursors@3"). Two elements of one array are two keys by it.
   type Symbol_Key is record
      Object    : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Component : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Path      : Ada.Strings.Unbounded.Unbounded_String;
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

   --  Path is the part of Actual the formal stands for, as in a
   --  Symbol_Key, where it is not the whole of it.
   type Frame_Object is record
      Formal : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Actual : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Path   : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Frame_Object_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Frame_Object);

   --  Scalars: each scalar formal bound, with the term of its actual.
   --  Objects: each other formal with the object that is its actual, and
   --  each blocked formal, of whatever type, with no object.
   type Contract_Frame is record
      Scalars : Symbolic_Binding_Vectors.Vector;
      Objects : Frame_Object_Vectors.Vector;
   end record;

   Empty_Contract_Frame : constant Contract_Frame :=
     (Scalars => Symbolic_Binding_Vectors.Empty_Vector,
      Objects => Frame_Object_Vectors.Empty_Vector);

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
