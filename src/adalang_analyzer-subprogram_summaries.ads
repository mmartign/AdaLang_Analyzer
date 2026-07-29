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
   --  Propagates raise/block effects through the call graph to a fixed point.

   function Callee_May_Block
     (Call : Libadalang.Analysis.Ada_Node'Class) return Boolean;

   function Callee_May_Raise
     (Call : Libadalang.Analysis.Ada_Node'Class) return Boolean;

   function Count return Natural;

end Adalang_Analyzer.Subprogram_Summaries;
