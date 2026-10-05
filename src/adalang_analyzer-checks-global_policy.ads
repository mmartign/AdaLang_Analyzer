--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Opt-in checks whose answer depends on sources other than the one being
--  walked: calls whose body is not available, chains of inlined calls, and
--  the two that compare every analyzed source with every other (integer
--  types never used as numbers, repeated instantiations). Each follows the
--  behaviour of the GNATcheck rule it is paired with in
--  benchmarks/gnatcheck_rule_map.tsv. Private to the Checks subsystem.
private package Adalang_Analyzer.Checks.Global_Policy is

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class);
   --  Runs every enabled check of this package keyed on Node's own kind.

   procedure Analyze_Sources
     (Ctx     : Libadalang.Analysis.Analysis_Context;
      Sources : Source_Lists);
   --  Runs the enabled checks that need all the sources at once. To be
   --  called after every file has been walked.

end Adalang_Analyzer.Checks.Global_Policy;
