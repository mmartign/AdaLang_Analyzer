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
--  at that aspect, where GNATprove reports its check, and it is the same
--  check: each output depends on what the aspect lists for it and on
--  nothing else. What each output may depend on is worked out from the
--  body, path by path: what is assigned to it, the conditions the
--  assignment is under, the conditions under which a loop goes round or
--  is left, under which a return is taken, and what each call makes of its
--  outputs, taken from the callee's Depends aspect or, when it has none,
--  from its body or its Global aspect. The components of a record object
--  are followed one by one, an array as a whole. The value on entry of an
--  out parameter or of an object the Global aspect lists as Output is no
--  input: reading it is an initialization error, the business of another
--  obligation. Proved_Safe when what is worked out is what the aspect
--  says; Unproved when the dependencies are not worked out, or differ.
--  Depends_Contract_Mismatch reports the differences.
package Adalang_Analyzer.Flow_Contracts is

   procedure Reset;
   --  Forgets what earlier runs established.

   procedure Verify_Unit (Unit : Libadalang.Analysis.Analysis_Unit);
   --  Raises the data-dependencies obligation of each subprogram body and
   --  expression function in Unit that has a Global aspect, and the
   --  flow-dependencies obligation of each one that has a Depends aspect.

   --  What Check_Depends finds of a Depends aspect.
   type Mismatch_Kind is
     (Not_Analyzed,
      --  The dependencies of the body were not worked out; Input says why.
      Unlisted_Output,
      --  Output, outside the body, is written and the aspect does not
      --  name it as an output.
      Missing_Flow,
      --  Output may depend on Input, which the aspect does not list for it.
      Extra_Flow,
      --  The aspect lists Input for Output, which does not depend on it.
      Proof_Flow);
      --  Output may depend on Input, which the Global aspect lists as
      --  Proof_In.

   procedure Check_Depends
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class;
      Depends    : Libadalang.Analysis.Expr'Class;
      Report     : not null access procedure
        (Kind : Mismatch_Kind; Output, Input : String));
   --  Works out what each output of Subprogram, a body or an expression
   --  function, may depend on and calls Report for each way that differs
   --  from its Depends aspect, the names given as written. Nothing but
   --  Not_Analyzed is reported when the dependencies are not worked out.

   function Touches_Nothing_Outside
     (Callee : Libadalang.Analysis.Basic_Decl'Class;
      Caller : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when a call to Callee made from Caller is known to read and to
   --  write no object declared outside Callee: its Global aspect is null,
   --  or it has none and its body, with all it calls, was followed to the
   --  end and touches none. A constant whose value depends on no variable
   --  is not such an object. False whenever the effects are not known.

end Adalang_Analyzer.Flow_Contracts;
