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

   procedure Check_Discriminant_Access
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Dotted_Name'Class);
   --  Reports Known_Discriminant_Check_Failure when Node selects a
   --  variant-part component that a statically known discriminant
   --  constraint on its prefix object provably excludes.

end Adalang_Analyzer.SPARK_Readiness;
