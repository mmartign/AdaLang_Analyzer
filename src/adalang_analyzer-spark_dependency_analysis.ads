--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Conservative input-to-output information-flow inference for SPARK
--  Depends contracts. This is a lightweight flow analysis, not a prover.
package Adalang_Analyzer.SPARK_Dependency_Analysis is

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body);

end Adalang_Analyzer.SPARK_Dependency_Analysis;
