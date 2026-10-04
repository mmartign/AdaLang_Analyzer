--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Opt-in naming-convention checks on defining names: casing, prefixes and
--  suffixes by kind of entity. Each reports nothing until the check
--  parameters that state the convention are given (see
--  Adalang_Analyzer.Config.Rule_Parameter), and follows the behaviour of
--  the GNATcheck rule it is paired with in
--  benchmarks/gnatcheck_rule_map.tsv. Private to the Checks subsystem.
private package Adalang_Analyzer.Checks.Naming is

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class);
   --  Runs the enabled naming checks when Node is a defining name.

end Adalang_Analyzer.Checks.Naming;
