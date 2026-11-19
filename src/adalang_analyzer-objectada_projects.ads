--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded;

with Adalang_Analyzer.Project_Files;

--  ObjectAda project files (.prj), as the Aonix ObjectAda IDE for Windows
--  writes them, and as the Atego and PTC releases that followed it still
--  do. Such a file is the binary archive (an MFC CArchive) of the IDE's
--  project: its targets, each with the list of its source files, then each
--  target's compiler, build and library options. Each source is listed
--  three times over: by its absolute path where the project was last
--  saved, by the name the IDE shows, and by its path relative to the
--  target's library directory, a directory of the project's own directory.
--  Only what the analysis needs is read: the sources, the name of the
--  library directory, and the library search path.
package Adalang_Analyzer.ObjectAda_Projects is

   Format_Error : exception;
   --  Raised, with a message that says what is wrong, for a file that is
   --  not an ObjectAda project file or whose list of sources cannot be
   --  read.

   type Project is record
      Target           : Ada.Strings.Unbounded.Unbounded_String;
      --  The name of the project's first target, such as
      --  "Win32 (Intel) Debug", or "" when it cannot be read.
      Listed           : Natural := 0;
      --  How many sources the project lists.
      Sources          : Project_Files.File_Name_Vectors.Vector;
      --  The listed sources found on this host, in the project's order.
      Missing          : Project_Files.File_Name_Vectors.Vector;
      --  The listed sources not found, as the project names them.
      Library_Sources  : Project_Files.File_Name_Vectors.Vector;
      --  The sources of the libraries on the project's search path, the
      --  ObjectAda run-time aside, whose own project file was found next
      --  to them, or that hold Ada sources themselves.
      Unresolved_Links : Project_Files.File_Name_Vectors.Vector;
      --  The entries of the search path, the run-time aside, for which
      --  no source was found.
   end record;

   function Is_ObjectAda_Project_Name (Name : String) return Boolean;
   --  True when Name ends in ".prj", in any case.

   function Load (Path : String) return Project;
   --  Reads the ObjectAda project file at Path and finds its sources, and
   --  those of the libraries it links to, on this host. A listed source is
   --  looked for first through its relative path, which still holds when
   --  the project has been moved or copied to another machine, then
   --  through its absolute path; on a host whose file names are case
   --  sensitive, a name that differs only in case from the one on disk is
   --  accepted, as Windows does. Raises Format_Error.

end Adalang_Analyzer.ObjectAda_Projects;
