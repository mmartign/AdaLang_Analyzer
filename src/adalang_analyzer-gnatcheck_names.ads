--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Adalang_Analyzer.Rules;

--  The GNATcheck rule names the checks answer to. A check keeps its own
--  name; the name of the GNATcheck rule it is paired with is accepted
--  wherever a check name is, so that a GNATcheck user can write
--  "-checks=positional_parameters" or "+RPositional_Parameters". One rule
--  name can stand for several checks (GNATcheck's null_paths is five checks
--  here), and one check can answer to several rule names.
--
--  The pairs are those of benchmarks/gnatcheck_rule_map.tsv and of the
--  configuration-paired table of docs/src/gnatcheck-rule-comparison.md;
--  tests/run_gnatcheck_names.sh checks that the three agree.
package Adalang_Analyzer.GNATcheck_Names is

   function Checks_For (Name : String) return Rules.Rule_List;
   --  The checks the GNATcheck rule Name stands for, or an empty list when
   --  Name is not a GNATcheck rule name. Case is not significant.

   function Names_Of (Rule : Rules.Rule_Kind) return String;
   --  The GNATcheck rule names Rule answers to, separated by ", ", or ""
   --  when it has none.

end Adalang_Analyzer.GNATcheck_Names;
