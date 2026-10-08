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

with Libadalang.Analysis;
with Libadalang.Common;

with Adalang_Analyzer.Flow_Domain;

--  The static evaluator: folds an AST expression into an
--  Adalang_Analyzer.Flow_Domain value using literals, constant
--  arithmetic, a flow-tracked identifier (via the Flow_State passed in by
--  the caller), and statically-decidable comparisons -- without executing
--  analyzed code or assuming a value when evaluation is incomplete. Drives
--  Division_By_Zero, Constant_Condition, Reversed_Range, and the
--  case-range checks. The statement-level interpreter that threads
--  Flow_State through a subprogram body (assignments, if/case/loop) lives
--  in Adalang_Analyzer.Flow_Interp, one layer up.
package Adalang_Analyzer.Flow_Eval is

   use Adalang_Analyzer.Flow_Domain;

   Floating_Zero_Tolerance : constant Long_Long_Float :=
     Long_Long_Float'Model_Epsilon;

   type Operator_Origin is (Predefined, Declared, Unresolved);

   function Origin_Of_Operator
     (Node : Libadalang.Analysis.Ada_Node'Class) return Operator_Origin;
   --  What the operator of Node, a unary or binary operation, denotes: the
   --  predefined operation its symbol stands for, a function a declaration
   --  defines, or what could not be established. Predefined for any other
   --  node, and for the short-circuit forms, ranges and membership tests,
   --  which no declaration can define.

   function Is_User_Operator
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is (Origin_Of_Operator (Node) /= Predefined);
   --  True when the operation Node is not known to be the arithmetic, the
   --  comparison or the logical operation its symbol stands for on its
   --  own: a call of a function a declaration defines says nothing of the
   --  kind about its operands (FP-116).

   function Integer_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State := Empty_Flow_State) return Abstract_Int;
   --  Statically evaluates Node as an integer expression when its value is
   --  determined purely by literals, constant arithmetic (+, -, abs, and
   --  the binary operators), a flow-tracked identifier, or an "if"
   --  expression whose condition itself resolves; Unknown_Int for anything
   --  that depends on an untracked variable, a function call, or
   --  unsupported syntax.

   function Boolean_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State := Empty_Flow_State) return Abstract_Bool;
   --  Statically evaluates Node as a boolean expression: the literals
   --  True/False, a flow-tracked boolean identifier, "not", "and"/"or"/
   --  "xor" (and their short-circuit forms), relational and equality
   --  comparisons on statically known integers, "= null"/"/= null", static
   --  membership tests, and an "if" expression whose condition itself
   --  resolves. Bool_Unknown for anything else.

   function Static_Condition_Value
     (Node : Libadalang.Analysis.Ada_Node'Class) return Abstract_Bool;
   --  What a rule check asks of a condition: whether it is constant as it
   --  is written. Boolean_Value with no state, but for a condition that
   --  names a named number, which is Bool_Unknown: the value of a named
   --  number is how a program is configured, and a test of it is the
   --  usual way of selecting code for one configuration, not a condition
   --  that has gone constant by mistake.

   function Expression_Modulus
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Is_Modular : out Boolean) return Abstract_Int;
   --  Is_Modular says whether the operator Node computes in a modular type
   --  (or in a type that cannot be shown not to be one); the result is its
   --  modulus when known. Integer_Value and Range_Value already reduce
   --  their results accordingly; this is for consumers that build their
   --  own terms.

   function Expanded_Name_Target
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node;
   --  For an expanded name of an object, of an enumeration literal or of
   --  a named number -- "Pkg.Obj", "Outer.Inner.Obj", "Subp.Local",
   --  "Pkg.Literal", "Pkg.Number" -- the final identifier, which resolves
   --  to the same defining name as the direct name; No_Ada_Node for
   --  anything else, a record component selection in particular. Every
   --  consumer of an identifier treats such a name as that identifier, so
   --  a fact held for the entity is the same fact whichever way it is
   --  named.

   function Named_Number_Value
     (Node : Libadalang.Analysis.Ada_Node'Class) return Abstract_Int;
   --  The value of the named number Node names, directly or by an
   --  expanded name, when its expression is one of integer literals, other
   --  such numbers, constants, T'First and T'Last, qualified expressions
   --  and the arithmetic operators, each operator taken in the type its
   --  operands give it. Unknown_Int for any other node, for a real number
   --  and for any other expression.

   function Is_Static_Zero
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node statically evaluates to 0, covering both integer and
   --  real literals.

   function Is_Static_One
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node statically evaluates to 1 (integer or real).

   function Is_Null_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node is (or parenthesizes/qualifies) the literal "null".

   function Is_Boolean_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node is the identifier "True" or "False" (case-insensitive)
   --  and names the literal: an object, a parameter or a function may be
   --  called True or False too, and hides it (FP-115).

   function Compare_Integers
     (Op   : Libadalang.Common.Ada_Node_Kind_Type;
      Left : Abstract_Int; Right : Abstract_Int) return Abstract_Bool;
   --  Evaluates a relational operator over two statically known integers;
   --  Bool_Unknown if either operand isn't known or Op isn't relational.

   function Range_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Abstract_Range;
   --  The Abstract_Range Node is statically known to fall within.

   function Compare_Range
     (Op   : Libadalang.Common.Ada_Node_Kind_Type;
      Left : Abstract_Range; Right : Abstract_Range) return Abstract_Bool;
   --  Evaluates a relational operator from two Abstract_Ranges, deciding
   --  the outcome only when one side's range is provably entirely above or
   --  below the other's.

   function Mirror_Comparison
     (Op : Libadalang.Common.Ada_Node_Kind_Type)
      return Libadalang.Common.Ada_Node_Kind_Type;
   --  Op with its operands conceptually swapped, e.g. Ada_Op_Lt <->
   --  Ada_Op_Gt. Eq/Neq are their own mirror.

   procedure Narrow_Identifier_By_Comparison
     (Key         : Libadalang.Analysis.Ada_Node;
      Op          : Libadalang.Common.Ada_Node_Kind_Type;
      Bound       : Abstract_Int;
      True_State  : in out Flow_State;
      False_State : in out Flow_State);
   --  Narrows Key's tracked range in True_State / False_State to reflect
   --  "Key <Op> Bound" holding or not holding, when Bound is statically
   --  known. A no-op when Bound isn't known or Key is null.

   procedure Narrow_By_Condition
     (Cond        : Libadalang.Analysis.Ada_Node'Class;
      State       : Flow_State;
      True_State  : out Flow_State;
      False_State : out Flow_State);
   --  Returns the states true after Cond holds (True_State) and after it
   --  doesn't (False_State), narrowing a tracked identifier's range for the
   --  handful of shapes this recognizes: a direct comparison against a
   --  statically known expression on either side, a membership test of an
   --  identifier against static values, ".." ranges and integer subtype
   --  marks, and "not"/"and"/"and then"/"or"/"or else" built from those.
   --  Anything else leaves both states identical to State, which is always
   --  sound.

   type Static_Interval is record
      Known : Boolean := False;
      Low   : Long_Long_Integer := 0;
      High  : Long_Long_Integer := 0;
   end record;

   function Choice_Interval
     (Choice : Libadalang.Analysis.Ada_Node'Class;
      State  : Flow_State := Empty_Flow_State) return Static_Interval;
   --  The [Low, High] range covered by one case choice: a single value for
   --  a plain expression, or the statically evaluated bounds of a ".."
   --  range choice. Known is False when either bound can't be evaluated.

   function Type_Size
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return Abstract_Int;
   --  Typ'Size for a static integer or enumeration subtype: the Size its
   --  first subtype is given by an aspect or a clause, for that subtype
   --  and for a subtype or a derived type that adds no constraint to it;
   --  otherwise the number of bits the values of the subtype take, with a
   --  sign bit only if one of them is negative and none at all when there
   --  is no value (RM 13.3(55), which GNAT follows). Unknown_Int for a
   --  type that is not discrete, for a generic formal type, a private
   --  type, a character type, an enumeration type with a representation
   --  clause, a range of an enumeration type, and for bounds that are not
   --  static.

   function Type_Range
     (Typ   : Libadalang.Analysis.Base_Type_Decl;
      State : Flow_State) return Abstract_Range;
   --  Best-effort integer bounds for a resolved discrete subtype. Bounds
   --  are expressions in Libadalang, so the same abstract state used for
   --  program expressions can also resolve named static bounds. A bound is
   --  resolved only when its value cannot have changed since the subtype
   --  was elaborated (it names constants, not variables); either side may
   --  be absent, and a caller that checks a value against the result needs
   --  both.

   function Discrete_Definition_Range
     (Definition : Libadalang.Analysis.Ada_Node'Class;
      State      : Flow_State) return Abstract_Range;
   --  The range one discrete_subtype_definition or index constraint
   --  denotes: "L .. H", a subtype mark, "S range L .. H" or "T'Range" of
   --  an integer or constrained array subtype T. A side is absent unless it is known as of the
   --  elaboration of the declaration Definition belongs to (see
   --  Type_Range).

   function Is_Elaboration_Stable
     (Expr : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Expr still has the value it had when the declaration it
   --  belongs to was elaborated: every name in it denotes a constant, a
   --  named number, an "in" parameter, a loop parameter, an enumeration
   --  literal, a subtype or a package.

   function Has_Subtype_Predicate
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return Boolean;
   --  True when Typ, or a subtype or derived type it is declared from,
   --  carries a Predicate, Static_Predicate or Dynamic_Predicate aspect, and
   --  also whenever that can't be established. The values of such a subtype
   --  are a subset of Type_Range, not all of it, so "X in Typ" is not a
   --  range test: a caller may still conclude that a member lies within
   --  Type_Range, but never that a value within Type_Range is a member.

   function Index_Constraint_Range
     (Constraint : Libadalang.Analysis.Constraint;
      Dimension  : Positive;
      State      : Flow_State) return Abstract_Range;
   --  The Dimension-th range of an index constraint such as the
   --  "(1 .. 10)" of "String (1 .. 10)"; Unknown_Range for any other
   --  constraint.

   function Array_Index_Range
     (Array_Type : Libadalang.Analysis.Base_Type_Decl;
      Dimension  : Positive;
      State      : Flow_State) return Abstract_Range;
   --  The bounds of Array_Type's Dimension-th index when the type itself
   --  fixes them: a constrained array definition, or a subtype or derived
   --  type that adds an index constraint. Unknown_Range for an
   --  unconstrained array type, whose index subtype says only what an
   --  object's bounds may be, never what they are.

   function Array_Object_Index_Range
     (Prefix    : Libadalang.Analysis.Ada_Node'Class;
      Dimension : Positive;
      State     : Flow_State) return Abstract_Range;
   --  The bounds of the Dimension-th index of the array object Prefix
   --  names: the index constraint on the object's or component's own
   --  declaration when it has one, otherwise Array_Index_Range of its
   --  type. Unknown_Range when Prefix isn't an array or its bounds aren't
   --  fixed by a declaration.

   function Length_Limits
     (Attribute : Libadalang.Analysis.Attribute_Ref) return Abstract_Range;
   --  What the type of its prefix says of X'Length or X'Length (N),
   --  whatever the state: from zero to the number of values of the index
   --  subtype of that dimension, which the bounds of an array that is not
   --  empty are in. Unknown_Range for any other attribute, and where the
   --  index subtype is not an integer one with static bounds.

   type Subtype_Constraint is record
      Present : Boolean := False;
      Bounds  : Abstract_Range := Unknown_Range;
   end record;
   --  What a declaration says about the values stored in what it declares
   --  beyond naming their type: the "range 1 .. 5" of "X : Integer range
   --  1 .. 5". Present when there is such a constraint, and also whenever
   --  that can't be ruled out; Bounds is then the range it denotes, a side
   --  absent unless it is known (see Discrete_Definition_Range), and it
   --  stands in for the range of the type.

   type Target_Subtype is record
      Typ        : Libadalang.Analysis.Base_Type_Decl :=
        Libadalang.Analysis.No_Base_Type_Decl;
      Constraint : Subtype_Constraint;
   end record;
   --  The subtype a value must belong to where it is stored.

   function Declared_Constraint
     (Indication : Libadalang.Analysis.Ada_Node'Class;
      State      : Flow_State) return Subtype_Constraint;
   --  The scalar constraint of the subtype indication of an object,
   --  component or array-component declaration (FP-107).

   function Stored_Subtype
     (Dest  : Libadalang.Analysis.Expr'Class;
      State : Flow_State) return Target_Subtype;
   --  The subtype of the variable Dest names, the target of an assignment:
   --  its type together with, for a scalar, the constraint of the
   --  declaration it comes from -- that of the object, of the record
   --  component, of the array type's components, of the access type's
   --  designated subtype, or of the object it renames. A Property_Error
   --  from resolving the type of Dest propagates.

   function Safe_Add
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int;

   function Safe_Sub
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int;

   function Safe_Mul
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int;

   function Safe_Pow
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int;
   --  Safe_Add/Sub/Mul/Pow fold a binary integer operation, collapsing to
   --  Unknown_Int on overflow rather than propagating Constraint_Error.

end Adalang_Analyzer.Flow_Eval;
