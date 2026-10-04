--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Opt-in readability, layout and size-limit checks: the ones that read
--  the token stream or a named check parameter (see
--  Adalang_Analyzer.Config.Rule_Parameter) rather than only the syntax
--  tree. Like Checks.Coding_Standard, each follows the behaviour of the
--  GNATcheck rule it is paired with in benchmarks/gnatcheck_rule_map.tsv.
--  Private to the Checks subsystem.
private package Adalang_Analyzer.Checks.Readability is

   procedure Analyze_Unit (Unit : Libadalang.Analysis.Analysis_Unit);
   --  Runs the checks that look at a whole compilation unit: its header,
   --  its length and its tokens. Called once per unit.

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class);
   --  Runs every enabled readability check keyed on Node's own kind.

end Adalang_Analyzer.Checks.Readability;
