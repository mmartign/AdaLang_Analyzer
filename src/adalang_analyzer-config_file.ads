--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded;

with Adalang_Analyzer.Project_Files;

--  Project-local configuration file support. The file is a small, diffable
--  plain-text format holding the same long-form flags accepted on the
--  command line, one or more per line, so a team can check a canonical
--  invocation into version control instead of reconstructing it by hand on
--  every run. '#'-prefixed and blank lines are comments, the same
--  convention Adalang_Analyzer.Report uses for its baseline file. There is
--  deliberately no separate key/value grammar: any flag CLI.Run already
--  understands works here too, and the two are merged by simply placing
--  this file's tokens ahead of the real command line, so a real flag
--  always overrides whatever the config file set.
package Adalang_Analyzer.Config_File is

   Default_Config_File_Name : constant String := "adalang_analyzer.cfg";

   type Resolution is record
      Path  : Ada.Strings.Unbounded.Unbounded_String;
      Found : Boolean;
   end record;

   function Resolve
     (Explicit_Path : String; No_Config : Boolean) return Resolution;
   --  Explicit_Path (from --config=<file>) takes precedence: Found is True
   --  only if that exact file exists, and the caller must treat a False
   --  result as a hard error since the file was explicitly requested.
   --  Otherwise, unless No_Config is set, looks for
   --  Default_Config_File_Name in the current working directory only (no
   --  parent-directory search). A False Found with an empty
   --  Explicit_Path is the common case (no config file involved) and is
   --  not an error.

   function Load_Tokens
     (Path : String) return Project_Files.File_Name_Vectors.Vector;
   --  Reads Path and splits it into whitespace-separated tokens in file
   --  order, skipping blank lines and lines whose first non-blank
   --  character is '#'. Propagates Ada.Text_IO exceptions on I/O failure,
   --  matching Adalang_Analyzer.Report.Load_Baseline.

end Adalang_Analyzer.Config_File;
