--  AdaLang Analyzer
--
--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--
--  Derived from AdaCore's libadalang-tools and substantially extended,
--  integrated, validated, and maintained by Spazio IT as part of the
--  independent AdaLang Analyzer project.
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

--  The command-line driver: option parsing, help/version/list-checks
--  text, project-file and source-file collection, and the per-file
--  processing loop with its summary output. Everything except Run is
--  private to this package's body; Adalang_Analyzer.Driver (the Main
--  procedure) is a one-line call to Run.
package Adalang_Analyzer.CLI is

   procedure Run;
   --  Parses Ada.Command_Line.Argument (1 .. Argument_Count), then either
   --  shows help/version/the check list, or analyzes the requested project
   --  and source files and prints the violation summary. Sets the process
   --  exit status via Ada.Command_Line.Set_Exit_Status, matching the
   --  original monolithic procedure's behavior.

end Adalang_Analyzer.CLI;
