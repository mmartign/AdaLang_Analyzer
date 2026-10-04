--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Opt-in coding-standard checks that need name resolution or type
--  information: positional associations, properties of the types and
--  subprograms a construct refers to, and the configurable lists of
--  forbidden aspects, attributes and dependences. Like
--  Checks.Coding_Standard, each follows the behaviour of the GNATcheck
--  rule it is paired with in benchmarks/gnatcheck_rule_map.tsv. Private to
--  the Checks subsystem.
private package Adalang_Analyzer.Checks.Typed_Policy is

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class);
   --  Runs every enabled check of this package keyed on Node's own kind.
   --  A Libadalang property failure in one check is confined to it.

end Adalang_Analyzer.Checks.Typed_Policy;
