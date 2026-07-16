--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Small abstract domains that support safe constant folding without
--  executing analyzed code or assuming a value when evaluation is
--  incomplete, and Flow_State: a flow-sensitive association from a
--  variable's defining name to what is statically known about it at one
--  point in a subprogram body. This package is the data model only; the
--  evaluator that produces these values from AST expressions lives in
--  Adalang_Analyzer.Flow_Eval, and the statement-level interpreter that
--  threads Flow_State through a subprogram body lives in
--  Adalang_Analyzer.Flow_Interp.
package Adalang_Analyzer.Flow_Domain is

   type Abstract_Bool is (Bool_Unknown, Bool_False, Bool_True);

   function Bool_Name (Value : Abstract_Bool) return String;

   function Not_Bool (Value : Abstract_Bool) return Abstract_Bool;

   function And_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool;

   function Or_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool;

   function Eq_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool;

   function Bool_From (Value : Boolean) return Abstract_Bool;

   type Abstract_Int is record
      Known : Boolean := False;
      Value : Long_Long_Integer := 0;
   end record;

   Unknown_Int : constant Abstract_Int := (Known => False, Value => 0);

   function Known_Int (Value : Long_Long_Integer) return Abstract_Int;

   --  A lower and/or upper bound a variable is known to stay within, even
   --  when its exact value isn't known. Either side can be absent on its
   --  own (Has_Low/Has_High), unlike Abstract_Int's all-or-nothing Known:
   --  "X > 0" only ever tells us a lower bound, never an upper one.
   type Abstract_Range is record
      Has_Low  : Boolean := False;
      Low      : Long_Long_Integer := 0;
      Has_High : Boolean := False;
      High     : Long_Long_Integer := 0;
   end record;

   Unknown_Range : constant Abstract_Range := (others => <>);

   function Range_From_Int (Value : Abstract_Int) return Abstract_Range;
   --  The range implied by a known exact value: both bounds equal Value.

   function Range_Union (Left, Right : Abstract_Range) return Abstract_Range;
   --  The tightest range covering both Left and Right.

   Max_Flow_Vars : constant := 64;

   --  A binding tracks the Abstract_Int, Abstract_Bool, and Abstract_Range
   --  a variable may be statically known to hold. Only one of Value /
   --  Bool_Value is ever meaningful for a given Decl (a variable's declared
   --  type is either integer or boolean, never both). Range_Value is
   --  meaningful only alongside Value, and is always at least as wide as
   --  the degenerate range implied by Value when Value is known.
   type Flow_Binding is record
      Decl        : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Value       : Abstract_Int := Unknown_Int;
      Bool_Value  : Abstract_Bool := Bool_Unknown;
      Range_Value : Abstract_Range := Unknown_Range;
   end record;

   type Flow_Binding_Array is array (1 .. Max_Flow_Vars) of Flow_Binding;

   type Flow_State is record
      Count    : Natural := 0;
      Bindings : Flow_Binding_Array;
   end record;

   Empty_Flow_State : constant Flow_State :=
     (Count => 0, Bindings => (others => <>));

   function Flow_Lookup
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Int;
   --  The Abstract_Int known for Key, or Unknown_Int if Key isn't tracked.

   function Flow_Bool_Lookup
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Bool;
   --  The Abstract_Bool known for Key, or Bool_Unknown if Key isn't tracked
   --  as a boolean.

   function Flow_Range_Lookup
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Range;
   --  The Abstract_Range known for Key, or Unknown_Range if Key isn't
   --  tracked.

   procedure Flow_Set
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node;
      Value : Abstract_Int);
   --  Records that Key now holds Value, replacing any prior binding, and
   --  widens its tracked range to at least the degenerate range implied by
   --  a known exact Value. Silently drops the update once Max_Flow_Vars
   --  bindings are in use.

   procedure Flow_Bool_Set
     (State      : in out Flow_State;
      Key        : Libadalang.Analysis.Ada_Node;
      Bool_Value : Abstract_Bool);
   --  Records that Key now holds Bool_Value, mirroring Flow_Set for the
   --  boolean half of a binding.

   procedure Flow_Range_Set
     (State       : in out Flow_State;
      Key         : Libadalang.Analysis.Ada_Node;
      Range_Value : Abstract_Range);
   --  Records that Key is now known to stay within Range_Value, without
   --  touching Value or Bool_Value.

   procedure Flow_Havoc
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node);
   --  Marks Key as no longer statically known in any domain, e.g. because
   --  it was passed to a call this analysis can't see through.

   function Flow_Join (Left, Right : Flow_State) return Flow_State;
   --  The state true after either of two branches: an exact-value binding
   --  survives only where both sides agree on the same known value; a
   --  range binding survives as the union of both sides' ranges.

end Adalang_Analyzer.Flow_Domain;
