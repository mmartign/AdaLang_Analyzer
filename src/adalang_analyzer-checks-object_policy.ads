--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Opt-in checks on program structure and object-oriented design: nesting
--  and hierarchy depth, tagged-type size and derivation, primitive
--  operation contracts and naming, and object initialization. Like
--  Checks.Coding_Standard, each follows the behaviour of the GNATcheck
--  rule it is paired with in benchmarks/gnatcheck_rule_map.tsv. Private to
--  the Checks subsystem.
private package Adalang_Analyzer.Checks.Object_Policy is

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class);
   --  Runs every enabled check of this package keyed on Node's own kind.
   --  A Libadalang property failure in one check is confined to it.

end Adalang_Analyzer.Checks.Object_Policy;
