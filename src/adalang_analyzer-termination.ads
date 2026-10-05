--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Termination: the obligation that a subprogram returns.
--
--  SPARK requires it of every function and of a procedure that has, or is
--  declared in a package that has, the aspect Always_Terminates. The
--  obligation is raised at the name of the subprogram in its first
--  declaration, which is where GNATprove reports its own check.
--
--  It is proved when the body is seen to terminate: it has no loop other
--  than a for loop over a discrete range or an array, no goto, no tasking
--  or delay, it calls nothing through an access value or by dispatching,
--  it is not recursive, directly or through what it calls, and each
--  subprogram it calls is seen to terminate in the same way from its own
--  body. A predefined operation, an intrinsic and a function of a
--  language-defined unit are taken to terminate. Calls that the source
--  does not show (a subtype predicate, a default initialization, a
--  finalization) are not followed.
--
--  Everything else is Unproved: the analysis never claims that a
--  subprogram does not terminate.
package Adalang_Analyzer.Termination is

   procedure Reset;
   --  Forgets what earlier runs established.

   procedure Verify_Unit (Unit : Libadalang.Analysis.Analysis_Unit);
   --  Raises the termination obligation of each subprogram body and
   --  expression function in Unit that SPARK requires to terminate.

end Adalang_Analyzer.Termination;
