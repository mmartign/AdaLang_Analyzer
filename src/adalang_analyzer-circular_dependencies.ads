--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

with Adalang_Analyzer.Project_Files;

--  Whole-program with-graph cycle detection. Unlike every check in
--  Adalang_Analyzer.Checks, which inspects one compilation unit's AST as it
--  is walked, Circular_Package_Dependency needs the full set of analyzed
--  units at once, so it runs as its own pass over Files after every file
--  has already been parsed into Ctx -- mirroring the whole-program pass
--  Adalang_Analyzer.Subprogram_Summaries already runs for a different
--  purpose.
package Adalang_Analyzer.Circular_Dependencies is

   procedure Analyze
     (Ctx   : Libadalang.Analysis.Analysis_Context;
      Files : Adalang_Analyzer.Project_Files.File_Name_Vectors.Vector);
   --  Builds a with-graph over Files (an edge only to another unit that is
   --  itself in Files; external/library units are outside the analyzed set
   --  and so cannot themselves complete a cycle back into it), then reports
   --  one Circular_Package_Dependency finding per elementary cycle found.

end Adalang_Analyzer.Circular_Dependencies;
