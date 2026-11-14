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

   function Result_Key
     (Subprogram : Libadalang.Analysis.Basic_Decl'Class)
      return Libadalang.Analysis.Ada_Node;
   --  What stands for the value a function returns (F'Result): the defining
   --  name of its first declaration.

   function Assign_Result
     (State    : Symbolic_State;
      Function_Key : Libadalang.Analysis.Ada_Node;
      Value    : Libadalang.Analysis.Expr'Class;
      Flow     : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State after a return of Value from the function whose Result_Key is
   --  Function_Key: the result has the term of Value. Where Value has none,
   --  State, in which nothing is said of the result.

   function Assume
     (State     : Symbolic_State;
      Condition : Libadalang.Analysis.Expr;
      Truth     : Boolean;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;

   function Assume_Alternative
     (State        : Symbolic_State;
      Selector     : Libadalang.Analysis.Expr'Class;
      Alternative  : Libadalang.Analysis.Ada_Node'Class;
      Alternatives : Libadalang.Analysis.Ada_Node'Class;
      Flow         : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State, with Selector, that of a case expression, one of the choices
   --  of Alternative, an element of the list Alternatives; for "others",
   --  none of the choices of the rest. State when a choice is not a value
   --  or a range the translation has a term for: nothing is assumed of it.

   function Assume_Predicate
     (State     : Symbolic_State;
      Object    : Libadalang.Analysis.Ada_Node'Class;
      Predicate : Libadalang.Analysis.Expr;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State;
      Part      : String := "")
      return Symbolic_State;
   --  State with Predicate assumed of a record object: the one whose
   --  defining name Object is, or the one, or the part of one, that Object
   --  names; of its component Part (".c", ".c.d") where Part is not empty.
   --  Predicate is the predicate aspect of a type or subtype declaration,
   --  written in terms of the current instance. It is taken part by part,
   --  as Assume takes a condition. State as it is where the object is not
   --  initialized in Flow or nothing could be taken. It is for the caller
   --  to say this only where the predicate holds.

   function Decide_Predicate
     (Predicate : Libadalang.Analysis.Expr;
      Value     : Libadalang.Analysis.Expr'Class;
      State     : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols   : Symbolic_State) return VC_Outcome;
   --  Whether Predicate, the predicate aspect of a type or subtype
   --  declaration written in terms of the current instance, holds of a
   --  value: of the value Value has in State and Symbols where the type is
   --  a scalar one, of the object, or the part of one, that Value names
   --  otherwise, as Symbols knows its components. A component that has not
   --  been written is a value of its subtype, as GNATprove takes it. A
   --  check cannot leave out what it does not express, as an assumption
   --  can: unsupported unless all of the predicate translates.

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

   procedure Set_Old_State
     (Flow    : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State;
      Frame   : Contract_Frame := Empty_Contract_Frame);
   --  From here on, until Clear_Old_State, X'Old is the value X has in
   --  Flow and Symbols, each scalar formal Frame binds having the term it
   --  gives: the state on entry for the postcondition of the subprogram
   --  verified, the state before a call, with the callee's formals bound
   --  there, for the callee's. Without it X'Old is not translated. It is
   --  for the caller to give a state that comes before the one X'Old is
   --  read in on every path, with no loop between the two.

   procedure Clear_Old_State;

   function Prime_Old
     (State     : Symbolic_State;
      Condition : Libadalang.Analysis.Expr;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State;
      Frame     : Contract_Frame := Empty_Contract_Frame)
      return Symbolic_State;
   --  State with a root for each part of an object that an X'Old of
   --  Condition reads, read in State and Flow, the formals Frame binds
   --  standing for what it binds: where X is written later on, the write
   --  renews it. Set_Old_State reads X'Old only through such roots.

   function With_Entry_Mark (State : Symbolic_State) return Symbolic_State;
   function Has_Entry_Mark (State : Symbolic_State) return Boolean;
   --  A mark that every transfer of a state keeps, a join keeps where both
   --  states have it, and that a state where names may stand for other
   --  values than they did -- Havoc, the entry of a loop body -- does not
   --  have. Where a state descended from one with the mark still has it,
   --  each symbol of that state names what it named there.

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
   --  neither, or when the formal is an array Actual slides to the bounds
   --  of (FP-135). It is for the caller to bind a formal only where
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
   --  Formal, a parameter of a record type, or of a constrained array
   --  subtype that Actual is of too, stands for the object Actual names, or
   --  for the part of one that the name settles, where that object is
   --  initialized in Flow: a part read through Formal is then the part of
   --  that object, known or not when the call is made. Frame is left as it
   --  is for any other formal or actual: an array of another subtype slides
   --  to the bounds of its own (FP-135), and one with the bounds of its
   --  actual has them from Bind_Actual. It is for the caller to bind a
   --  formal only where the condition is evaluated with Actual holding the
   --  value it has in State.

   --  A call the translation cannot look into is still a term when it is
   --  to a function of its arguments: one with no side effect whose result
   --  depends on nothing but the values it is given, which an access value
   --  is not: what it designates is read, and can change while it stands
   --  (FP-136). Two such calls with
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

   --  Which objects have relaxed initialization (SPARK RM 6.10). A part of
   --  one, read in the expression being decided, is taken as having a
   --  value whatever the state says of the whole object: that read is
   --  checked where it is, as GNATprove checks it. Read through a formal
   --  bound to it, or in an inlined body, it is not. Without an oracle no
   --  object is taken to have relaxed initialization.
   type Relaxed_Oracle is access function
     (Key : Libadalang.Analysis.Ada_Node) return Boolean;

   procedure Set_Relaxed_Oracle (Oracle : Relaxed_Oracle);

   type Loop_Fixed_Oracle is access function
     (Name      : Libadalang.Analysis.Ada_Node;
      Loop_Node : Libadalang.Analysis.Ada_Node) return Boolean;
   procedure Set_Loop_Fixed_Oracle (Oracle : Loop_Fixed_Oracle);
   --  Asked of a name in a bound of the range of a for loop: True when
   --  the loop writes nothing it denotes. Ada evaluates the range once,
   --  where the loop is entered, so such a bound has its value on entry
   --  all through the loop (Loop_Bound_Terms).

   Default_Solver_Time_Limit : constant := 2_000;
   procedure Set_Solver_Time_Limit (Milliseconds : Positive);
   --  The time each solver is given for one query, in milliseconds;
   --  Default_Solver_Time_Limit unless set.

   procedure Forget_Declared_Facts;
   --  Empties the memos of the ranges of component subtypes and the sorts
   --  of types, which may read the values of formals: before and after an
   --  instance pass of a generic unit.

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

   function Forget_Element_Values
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class) return Symbolic_State;
   --  As Forget_Composite_Values, for Writer a write to elements of an
   --  array, whichever array it is, in code where no object a parameter
   --  passed by reference stands for is also reached by another name: what
   --  State says of an access value stands too, unless the access value is
   --  in an element. A write through an access value changes what it
   --  designates, not the access value.

   function Forget_Elements
     (State   : Symbolic_State;
      Writer  : Libadalang.Analysis.Ada_Node'Class;
      Written : Libadalang.Analysis.Ada_Node) return Symbolic_State;
   --  State after Writer has assigned elements of the array object whose
   --  defining name is Written, for code where no other object shares its
   --  storage nor is designated by an access value: as
   --  Forget_Composite_Values for the object and for every object that
   --  renames another, what State says of the other objects standing.

   function Forget_Designated
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class) return Symbolic_State;
   --  State after Writer has written through an access value, in code where
   --  what an access value designates is no object with a name of its own
   --  (SPARK code that takes no 'Access or 'Address of anything): as
   --  Forget_Element_Values, what State says of a scalar in an element of an
   --  object standing too. A write there reaches no named part of any
   --  object. A value that is not a scalar gets a value of its own: a
   --  function given it may read through an access value it holds.

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

   function Store_Element
     (Before      : Symbolic_State;
      After       : Symbolic_State;
      Destination : Libadalang.Analysis.Name'Class;
      Value       : Libadalang.Analysis.Expr'Class;
      Writer      : Libadalang.Analysis.Ada_Node'Class;
      Flow        : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  After, the state Writer, the assignment of Value to Destination,
   --  left from Before, Flow being the flow state before it: where
   --  Destination is the scalar element of a one-dimensional array with an
   --  integer index, an object or a part of one that the name settles,
   --  with the contents of the array's value after the write (Selected_
   --  Element_Term in the body) those of its value in Before with the
   --  element at the index the value of Value -- a value of which nothing
   --  is known where Value has no term. After must be a state in which the
   --  write renewed what it may have changed (Forget_Elements and the
   --  like); the value of the array gets a token of its own there if the
   --  write did not give it one. After as it is for any other Destination,
   --  or where the index has no term.

   function Prime_Initialized_Range
     (State  : Symbolic_State;
      Target : Libadalang.Analysis.Ada_Node'Class;
      Flow   : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State with a root for each name that Store_Initialized_Range reads
   --  of Target, an element or a slice of an array of an object with
   --  relaxed initialization: a write after that renews what it changes,
   --  and the roots keep the values of before.

   function Store_Initialized_Range
     (Before      : Symbolic_State;
      After       : Symbolic_State;
      Target      : Libadalang.Analysis.Ada_Node'Class;
      Writer      : Libadalang.Analysis.Ada_Node'Class;
      Flow        : Adalang_Analyzer.Flow_Domain.Flow_State;
      Primed_Only : Boolean) return Symbolic_State;
   --  After, the state after Writer gave every element of Target a value
   --  -- the element X (I) of an array, or the slice X (L .. H) of one, X
   --  an object with relaxed initialization -- with the initialization of
   --  the elements of the new value of X (a token of its own) that of the
   --  value before, Target's elements having one. Target is read in
   --  Before, the state before the write, and Flow; with Primed_Only,
   --  only through names Before has (Prime_Initialized_Range). After as it
   --  is for any other Target.

   function Assign_Contents
     (Before : Symbolic_State;
      After  : Symbolic_State;
      Target : Libadalang.Analysis.Ada_Node;
      Value  : Libadalang.Analysis.Expr'Class;
      Writer : Libadalang.Analysis.Ada_Node'Class;
      Flow   : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  As Store_Element, for Writer giving the whole one-dimensional array
   --  object whose defining name is Target the value of Value: the contents
   --  of its new value are those Value says -- an aggregate with "others"
   --  or of positions, or of named choices that cover the bounds of the
   --  target; another array's, where the two have one first bound term;
   --  another's with elements replaced ('Update, a delta aggregate). After
   --  must be a state in which the write renewed the object; After as it
   --  is for any other value.

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
   --  the component the value's term when it is a scalar, the parts of a
   --  record what State says of those of the record Value names (With_Parts_
   --  Of), and what State says of the other parts of the object stands.
   --  Shared when another
   --  name may denote the object -- two parameters passed by reference, a
   --  parameter and a global, outside SPARK code: then every part of every
   --  other object gets a value of its own too. Havoc for any other
   --  destination.

   function With_Parts_Of
     (State  : Symbolic_State;
      Prior  : Symbolic_State;
      Target : Libadalang.Analysis.Ada_Node;
      Value  : Libadalang.Analysis.Expr'Class;
      Flow   : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State, in which the object Target has just been given Value and holds
   --  a value of its own, with what Prior, the state before, says of the
   --  parts of the record Value names said of the parts of Target as well:
   --  the two are equal, component by component. State for any other Value.

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

   function Forget_Element_Part
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class;
      Dest   : Libadalang.Analysis.Name'Class;
      After  : Adalang_Analyzer.Flow_Domain.Flow_State;
      Shared : Boolean) return Symbolic_State;
   --  State after Writer, an assignment, has written Dest, an element of an
   --  array that is a part of a tracked object the name settles ("Ctx.Cur
   --  (F)"), in code where no access value designates such an object nor
   --  any part of it: each key of what overlaps the element gets a value of
   --  its own where the index is known (Is_Settled_Part of Dest), and each
   --  key of what overlaps the array otherwise; so does each value and each
   --  element of an object that renames another, or that is no object nor
   --  parameter. What State says of the other parts of the object, and of
   --  other objects, stands -- unless Shared, another name may then denote
   --  the object: each part of every other object gets a value of its own
   --  too. Havoc where neither Dest nor the array is settled.

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

   function Decide_Initialized_Read
     (Name    : Libadalang.Analysis.Ada_Node'Class;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome;
   --  Decides that every element of Name -- the element X (I) of an array,
   --  the slice X (L .. H) of one, or the whole X -- has a value, the
   --  array being an object with relaxed initialization: from what the
   --  writes and the conditions that hold said of the initialization of
   --  its elements. VC_Unsupported for any other name.

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

   type Slice_Bound is (Low_Bound, High_Bound, Both_Bounds);

   function Decide_Slice_Bounds
     (Low, High : Libadalang.Analysis.Expr'Class;
      Prefix    : Libadalang.Analysis.Name'Class;
      Bounds    : Adalang_Analyzer.Flow_Domain.Abstract_Range;
      Which     : Slice_Bound;
      State     : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols   : Symbolic_State) return VC_Outcome;
   --  Decides that the bound or bounds Which of the slice
   --  Prefix (Low .. High) are within the index bounds of Prefix whenever
   --  the slice is not null: "Low <= High implies ...". The index bounds
   --  are Bounds where it has both, and otherwise Prefix'First and
   --  Prefix'Last as Decide_Index_In_Object takes them. Ada does not check
   --  the bounds of a null slice, so this is the whole of the check, of
   --  which Decide_Bounds and Decide_Index_In_Object prove the part that
   --  holds whether the slice is null or not.

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

   function Array_Bound_Facts
     (State    : Symbolic_State;
      Standing : access function
        (Object : Libadalang.Analysis.Ada_Node) return Boolean := null)
      return Symbolic_State;
   --  What State knows about the bounds and lengths of array objects, and
   --  nothing else. Those never change while the objects are visible, so
   --  such facts survive where every fact about a variable must be
   --  dropped, at the entry of a loop body in particular. Where Standing
   --  is given, what State knows of the values of the objects whose
   --  defining name it is True for is kept too -- of a scalar object, or of
   --  the whole value of one that is not, the contents of an array
   --  included -- alone or together with those bounds: it is for the
   --  caller to say so only of objects whose value nothing changes where
   --  the result is used.

   procedure Assume_Last_Iteration
     (State         : in out Symbolic_State;
      Standing      : Symbolic_State;
      Parameter     : Libadalang.Analysis.Ada_Node;
      Iteration     : Libadalang.Analysis.Ada_Node'Class;
      Reverse_Order : Boolean;
      Flow          : Adalang_Analyzer.Flow_Domain.Flow_State;
      Done          : out Boolean);
   --  State, at the end of an iteration of a loop over Iteration whose
   --  parameter is Parameter, as at the end of the last one: the
   --  parameter is the last value of the range, Done. Only where the
   --  bounds cannot change during the loop (as for Next_Iteration) and
   --  Standing, what holds wherever the loop is entered, shows that the
   --  range is not empty: then a way out of the loop that no exit
   --  statement takes follows a last iteration. State as it is, not Done,
   --  otherwise.

   function Entry_Loop
     (Attribute : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node;
   --  The loop whose entry X'Loop_Entry, Attribute, is the value of X at:
   --  the innermost loop statement Attribute is in, within the body it is
   --  in. No_Ada_Node for anything else, and for X'Loop_Entry (L), which
   --  names its loop.

   function Enter_Loop
     (State     : Symbolic_State;
      Loop_Node : Libadalang.Analysis.Ada_Node'Class;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State on a way into the loop statement Loop_Node, Flow being the
   --  flow state there, with each X'Loop_Entry of that loop (Entry_Loop)
   --  given a root of its own, equal to the term of X in State, where X
   --  translates and names nothing declared in the loop. That root is the
   --  value of X'Loop_Entry in the loop (Symbol_For): no write renews it,
   --  and Array_Bound_Facts keeps it where Standing is True for the
   --  attribute reference. Where State already speaks of it, which only a
   --  way that passes no loop head can, all but what Array_Bound_Facts
   --  keeps is dropped first.

   function Assume_Loop_Range
     (State      : Symbolic_State;
      Parameter  : Libadalang.Analysis.Ada_Node;
      Iteration  : Libadalang.Analysis.Ada_Node'Class;
      Flow       : Adalang_Analyzer.Flow_Domain.Flow_State;
      Fixed_Only : Boolean := True)
      return Symbolic_State;
   --  State with the fact that the loop parameter whose defining name is
   --  Parameter lies within Iteration, the loop's own "A'Range" or
   --  "Low .. High". With Fixed_Only, only bounds whose value cannot
   --  change during the loop are used; otherwise State is returned as it
   --  is. Without, the bounds are read in State: for the parameter of a
   --  quantified expression, where its predicate is evaluated.

   type Loop_Step is (First_Iteration, Next_Iteration);

   function Step_Loop_Parameter
     (State         : Symbolic_State;
      Parameter     : Libadalang.Analysis.Ada_Node;
      Iteration     : Libadalang.Analysis.Ada_Node'Class;
      Reverse_Order : Boolean;
      Step          : Loop_Step;
      Flow          : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State with what is known of the loop parameter whose defining name is
   --  Parameter, of a loop over Iteration (as for Assume_Loop_Range) that
   --  goes up, or down with Reverse_Order. First_Iteration: the loop is
   --  entered, and the parameter is the first value of its range; the
   --  bounds are taken as they are in State, where the loop is entered.
   --  Next_Iteration: the value the parameter had was not the last, and
   --  it now has the next one, under a name of its own -- once per state;
   --  only bounds whose value cannot change during the loop are used.
   --  Where the range cannot be told: State as it is on the first
   --  iteration, and on the next State with the parameter under a name of
   --  its own that nothing relates to the value before (Havoc where that
   --  name is taken).

   function Decide_Nonzero
     (Value   : Libadalang.Analysis.Expr'Class;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome;
   --  As Decide_Bounds, for Division_By_Zero_Check's "divisor /= 0" goal,
   --  which Abstract_Range cannot express (a single excluded point, not a
   --  bound).

   function Decide_Not_Null
     (Value   : Libadalang.Analysis.Expr'Class;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome;
   --  As Decide_Nonzero, for Pointer_Dereference_Check's "Value /= null"
   --  goal, Value being of an access type.

   type Part_Path_List is
     array (Positive range <>) of Ada.Strings.Unbounded.Unbounded_String;
   --  Parts of an object, each as the way to it from the object: "" for
   --  the object itself, ".c" for its component C, ".c.d" and so on.

   function Decide_Parts_Null
     (Base    : Libadalang.Analysis.Ada_Node'Class;
      Paths   : Part_Path_List;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome;
   --  Resource_Leak_Check's goal: each access part Paths gives of the
   --  object Base is null. Base is a name, or the defining name of an
   --  object.

   function Null_Parts
     (Symbols : Symbolic_State;
      Base    : Libadalang.Analysis.Ada_Node'Class;
      Paths   : Part_Path_List;
      Writer  : Libadalang.Analysis.Ada_Node'Class;
      Flow    : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  Symbols with each access part Paths gives of Base null: the value an
   --  object of an access type has by default, and the one an owning part
   --  stands for once it is moved, which SPARK code does not read again
   --  before it is assigned. Symbols where Base is no object the state
   --  follows.

   function Is_Discriminated_Record
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return Boolean;
   --  True when Typ is, seen through subtypes and a private view, a record
   --  type that is not tagged and has known discriminants: one whose
   --  assignment Decide_Discriminants_Kept decides.

   function Decide_Variant_Selection
     (Selected : Libadalang.Analysis.Dotted_Name'Class;
      State    : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols  : Symbolic_State) return VC_Outcome;
   --  As Decide_Not_Null, for Discriminant_Check's goal at Selected, a
   --  component of a variant part read or written: the discriminant of
   --  each variant part the component is in, of the record the prefix
   --  names, is one of the choices of the variant that declares it ("others"
   --  standing for none of the other variants' choices).

   function Decide_Discriminants_Kept
     (Target  : Libadalang.Analysis.Name'Class;
      Value   : Libadalang.Analysis.Expr'Class;
      State   : Adalang_Analyzer.Flow_Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome;
   --  As Decide_Variant_Selection, for the assignment of Value to Target, a
   --  record with discriminants: Target is not constrained (RM 3.7.2), or
   --  each discriminant of Value is that of Target. The discriminants of
   --  Value are those an aggregate gives, those of the record a name, an
   --  'Update or a delta aggregate starts from. The outcome is VC_Refuted
   --  only where both Target'Constrained and the discriminants of Value are
   --  known: discriminants that differ fail the check only where the target
   --  is constrained, and a constrained target only where they differ.

   function With_Declared_Discriminants
     (State     : Symbolic_State;
      Object    : Libadalang.Analysis.Ada_Node;
      Type_Expr : Libadalang.Analysis.Type_Expr'Class;
      Flow      : Adalang_Analyzer.Flow_Domain.Flow_State)
      return Symbolic_State;
   --  State once the object whose defining name is Object is declared with
   --  Type_Expr: where that gives a discriminant constraint, the object's
   --  discriminants are its values, read in Flow and State. State
   --  otherwise.

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
   --  and good only as an argument of a function term, the contents of an
   --  array (Selected_Element_Term in the body) being one.

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
