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

   function Count return Natural;

end Adalang_Analyzer.Subprogram_Summaries;
