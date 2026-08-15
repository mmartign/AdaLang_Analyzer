--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

with Adalang_Analyzer.Project_Files;

--  Whole-program duplicate-subprogram-body detection. Like
--  Adalang_Analyzer.Circular_Dependencies, this needs every analyzed unit
--  at once rather than one compilation unit's AST as it is walked, so it
--  runs as its own pass over Files after every file has already been
--  parsed into Ctx.
package Adalang_Analyzer.Clone_Detection is

   procedure Analyze
     (Ctx   : Libadalang.Analysis.Analysis_Context;
      Files : Adalang_Analyzer.Project_Files.File_Name_Vectors.Vector);
   --  Collects every subprogram body (Ada_Subp_Body, at any nesting depth)
   --  across Files whose whitespace/case-normalized statement-list text is
   --  at least Minimum_Signature_Length characters long, groups them by
   --  that text, and reports one Duplicate_Subprogram finding for every
   --  body after the first in each group of two or more identical bodies.
   --  A trivial body (a common, usually-intentional shape: "null;",
   --  "return X;", a one-line accessor) is exempt so the check stays about
   --  real copy-paste risk rather than boilerplate coincidence.

end Adalang_Analyzer.Clone_Detection;
