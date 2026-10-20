--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Depends_Contract_Mismatch: what a SPARK Depends contract gets wrong.
--  Where the flow-dependencies analysis of Flow_Contracts works out what
--  each output may depend on, each difference from the contract: a flow
--  the contract does not list, a listed flow that does not exist, a flow
--  from a Proof_In global. Where it does not, no flow is reported. And,
--  read from the contracts alone: an input of the subprogram the contract
--  does not mention, a name the contract lists as an input that is none.
package Adalang_Analyzer.SPARK_Dependency_Analysis is

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body);

end Adalang_Analyzer.SPARK_Dependency_Analysis;
