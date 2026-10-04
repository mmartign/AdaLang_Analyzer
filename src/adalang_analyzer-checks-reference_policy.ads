--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Opt-in checks that follow references within a compilation unit: where
--  an object is used relative to where it is declared, repeated or
--  contradictory tests in a condition, exceptions leaving the scope that
--  declares them, and differences between a body's profile and its
--  declaration. Each follows the behaviour of the GNATcheck rule it is
--  paired with in benchmarks/gnatcheck_rule_map.tsv. Private to the
--  Checks subsystem.
private package Adalang_Analyzer.Checks.Reference_Policy is

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class);
   --  Runs every enabled check of this package keyed on Node's own kind.

end Adalang_Analyzer.Checks.Reference_Policy;
