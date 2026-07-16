--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
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
