--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  The obligations a subprogram takes on with its flow contracts.
--
--  Data dependencies: a subprogram with a Global aspect reads and writes no
--  object declared outside it that the aspect does not allow. The
--  obligation is raised at the aspect, which is where GNATprove reports its
--  check, and it is the same check: each such object the body may read is
--  to be listed, with a mode other than Proof_In unless it is only read in
--  assertions, and each one it may write is to be listed as Output or
--  In_Out. An entry of the aspect that the body does not use, or uses less
--  than its mode allows, does not fail it.
--
--  It is proved from an over-approximation of what the body touches: every
--  name in it that denotes an outside object, through renamings and
--  dereferences, and the effects of every subprogram it calls, taken from
--  that subprogram's own Global aspect or, when it has none, worked out from
--  its body in the same way. Where the effects of a callee are not known --
--  no contract and no body, a call that dispatches or goes through an access
--  value, recursion without a contract -- the obligation is Unproved, as it
--  is when something the body touches is not allowed by the aspect.
--
--  Flow dependencies: a subprogram with a Depends aspect has an obligation
--  at that aspect, where GNATprove reports its check. No route proves it
--  yet: it is Unproved wherever it is raised. A dependency that is missing
--  is reported by Depends_Contract_Mismatch as before.
package Adalang_Analyzer.Flow_Contracts is

   procedure Reset;
   --  Forgets what earlier runs established.

   procedure Verify_Unit (Unit : Libadalang.Analysis.Analysis_Unit);
   --  Raises the data-dependencies obligation of each subprogram body and
   --  expression function in Unit that has a Global aspect, and the
   --  flow-dependencies obligation of each one that has a Depends aspect.

end Adalang_Analyzer.Flow_Contracts;
