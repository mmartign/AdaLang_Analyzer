--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  A bounded-cost, whole-input call-summary registry. It deliberately records
--  small monotone effects rather than paths or complete program states, so a
--  transitive fixed point remains cheap enough for the normal analysis mode.
package Adalang_Analyzer.Subprogram_Summaries is

   procedure Reset;

   procedure Scan_Unit (Unit : Libadalang.Analysis.Analysis_Unit);
   --  Registers every subprogram body in Unit and its direct calls, raise
   --  statements, delay statements, and entry calls.

   procedure Complete;
   --  Propagates raise/block and state-write effects through the call graph to
   --  a fixed point. A state-effect summary is complete only when every call
   --  reachable from the body resolves to another registered body.

   function Callee_May_Block
     (Call : Libadalang.Analysis.Ada_Node'Class) return Boolean;

   function Callee_May_Raise
     (Call : Libadalang.Analysis.Ada_Node'Class) return Boolean;

   function Callee_State_Effects_Known
     (Call : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True only when the callee body and every transitive call contributing
   --  state effects were resolved. False requires the consumer's conservative
   --  unknown-call fallback.

   function Callee_Global_Write_Count
     (Call : Libadalang.Analysis.Ada_Node'Class) return Natural;

   function Callee_Global_Write
     (Call  : Libadalang.Analysis.Ada_Node'Class;
      Index : Positive) return String;
   --  Stable declaration/name keys for nonlocal objects the callee may write,
   --  including writes propagated from transitive callees.

   function Callee_Formal_May_Write
     (Call   : Libadalang.Analysis.Ada_Node'Class;
      Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean;

   function Callee_Formal_May_Read
     (Call   : Libadalang.Analysis.Ada_Node'Class;
      Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean;

   function Callee_Formal_Definitely_Writes
     (Call   : Libadalang.Analysis.Ada_Node'Class;
      Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean;
   --  The latter is deliberately narrower than mode `out`: it is true only
   --  when the registered body establishes a write on every normal return.
   --  That is read from the statements of the body alone, so it holds
   --  whether or not the other effects of the body are known. It is the
   --  body of the subprogram the call names: a dispatching call may run
   --  another, and the caller has to leave those out.

   --  A generic unit has no SPARK_Mode of its own unless it says so: it has
   --  that of the place it is instantiated in. The instantiations Scan_Unit
   --  meets are kept, each with the generic unit it is of, whether it is
   --  under an explicit SPARK_Mode, and the generic unit it is itself part
   --  of, if any.

   type Mode_Oracle is access function
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean;

   procedure Set_SPARK_Mode_Oracle (Oracle : Mode_Oracle);
   --  Oracle says whether a declaration is under an explicit SPARK_Mode
   --  (On). Without one no instantiation is taken to be.

   function Generic_Unit_Key
     (Node : Libadalang.Analysis.Ada_Node'Class) return String;
   --  A key for the generic unit Node is part of, its declaration or its
   --  body; "" when it is part of none.

   function Instantiated_In_SPARK (Key : String) return Boolean;
   --  True when the generic unit of that key is instantiated in the units
   --  of this run, and every one of its instantiations there is under an
   --  explicit SPARK_Mode or part of a generic unit of which the same
   --  holds.

   function Count return Natural;

end Adalang_Analyzer.Subprogram_Summaries;
