--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Opt-in coding-standard policy checks: construct restrictions and naming
--  of compound statements that project coding standards commonly impose.
--  None of them belongs to a preset; each is selected by name. Their scope
--  follows the behaviour of the GNATcheck rule each one is paired with in
--  benchmarks/gnatcheck_rule_map.tsv, so the two tools can be compared
--  line for line. Private to the Checks subsystem.
private package Adalang_Analyzer.Checks.Coding_Standard is

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class);
   --  Runs every enabled coding-standard check keyed on Node's own kind.
   --  Each check is confined to its own handler, so a Libadalang property
   --  failure in one cannot suppress the others on the same node.

end Adalang_Analyzer.Checks.Coding_Standard;
