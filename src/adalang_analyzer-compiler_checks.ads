--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Adalang_Analyzer.Project_Files;

--  The three checks that report what the GNAT compiler itself detects:
--  Compiler_Warning, Compiler_Style_Check and Compiler_Restriction. They
--  correspond to GNATcheck's Warnings, Style_Checks and Restrictions rules,
--  which work the same way. The sources are compiled for semantic checks
--  only, with the switches the check parameters select, in a temporary
--  directory; nothing is written next to the sources.
package Adalang_Analyzer.Compiler_Checks is

   type Source_Set is record
      Files         : Project_Files.File_Name_Vectors.Vector;
      --  The analyzed files: only messages located in them are reported.
      Lookup_Files  : Project_Files.File_Name_Vectors.Vector;
      --  Files whose directories hold the other units the analyzed ones
      --  depend on. Used when there is no project.
      Projects      : Project_Files.File_Name_Vectors.Vector;
      --  The project files given, if any.
      Scenario_Vars : Project_Files.File_Name_Vectors.Vector;
      --  "name=value" pairs for the projects.
   end record;

   procedure Analyze (Sources : Source_Set);
   --  Runs the enabled and configured compiler checks and reports a
   --  finding for each selected message located in one of the analyzed
   --  files. With projects, each one is compiled through gprbuild;
   --  otherwise each analyzed file is compiled with gcc. When the
   --  compiler cannot be found, a warning is printed and nothing is
   --  reported.

end Adalang_Analyzer.Compiler_Checks;
