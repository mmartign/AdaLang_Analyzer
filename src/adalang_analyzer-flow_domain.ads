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

with Ada.Containers.Vectors;

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
      Initialized : Abstract_Bool := Bool_Unknown;
   end record;

   type Flow_State is private;

   Empty_Flow_State : constant Flow_State;

   function Binding_Count (State : Flow_State) return Natural;

   function Binding_At
     (State : Flow_State;
      Index : Positive) return Flow_Binding;
   --  Read-only enumeration for assurance backends that must encode every
   --  abstract-state constraint. Raises Constraint_Error for an invalid
   --  index.

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

   function Flow_Initialization
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Bool;

   procedure Flow_Set_Initialized
     (State       : in out Flow_State;
      Key         : Libadalang.Analysis.Ada_Node;
      Initialized : Abstract_Bool);

   procedure Flow_Set
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node;
      Value : Abstract_Int);
   --  Records that Key now holds Value, replacing any prior binding, and
   --  widens its tracked range to at least the degenerate range implied by
   --  a known exact Value. The state grows dynamically; facts are never
   --  silently dropped because an implementation capacity was reached.

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

   procedure Flow_Havoc_All (State : in out Flow_State);
   --  Discards every tracked binding. The conservative fallback when a
   --  call's effects on state outside its own actual parameters can't be
   --  determined at all (unresolved callee, or no Global contract to name
   --  what it may write), so nothing previously known can be trusted to
   --  have survived the call.

   function Flow_Join (Left, Right : Flow_State) return Flow_State;
   --  The state true after either of two branches: an exact-value binding
   --  survives only where both sides agree on the same known value; a
   --  range binding survives as the union of both sides' ranges.

   function Flow_Equal (Left, Right : Flow_State) return Boolean;
   --  Semantic equality used to detect fixed-point convergence.

   function Flow_Widen
     (Previous, Next : Flow_State) return Flow_State;
   --  Standard interval widening: a bound that moves outwards becomes
   --  unbounded. Exact integers and Boolean facts survive only when stable.

private

   package Flow_Binding_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Flow_Binding);

   type Flow_State is record
      Bindings : Flow_Binding_Vectors.Vector;
   end record;

   Empty_Flow_State : constant Flow_State :=
     (Bindings => Flow_Binding_Vectors.Empty_Vector);

end Adalang_Analyzer.Flow_Domain;
