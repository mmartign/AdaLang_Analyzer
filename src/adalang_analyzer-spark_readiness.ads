--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Lightweight SPARK Bronze/readiness checks. This package deliberately
--  checks properties that can be established from Libadalang's semantic AST
--  without attempting to reproduce GNATprove's proof engine.
package Adalang_Analyzer.SPARK_Readiness is

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body);

end Adalang_Analyzer.SPARK_Readiness;
