--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
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
   --  True when Node is the identifier "True" or "False" (case-insensitive),
   --  i.e. a syntactic boolean literal rather than an evaluated expression.

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
   --  statically known expression on either side, and "not"/"and"/
   --  "and then"/"or"/"or else" built from such comparisons. Anything else
   --  leaves both states identical to State, which is always sound.

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
