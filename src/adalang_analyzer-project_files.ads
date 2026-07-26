--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Vectors;

--  GNAT project (.gpr) file support backed by GPR2. Project expressions,
--  scenario variables, naming rules, exclusions, recursive source
--  directories, and project extension are evaluated by the GPR2 library.
package Adalang_Analyzer.Project_Files is

   package File_Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   procedure Load_Project_File
     (Project_File  : String;
      Files         : in out File_Name_Vectors.Vector;
      Seen          : in out File_Name_Vectors.Vector;
      Scenario_Vars : File_Name_Vectors.Vector := File_Name_Vectors.Empty_Vector);
   --  Loads Project_File (appending ".gpr" if omitted) with GPR2 and appends
   --  the visible Ada sources of its root project to Files. Seen avoids
   --  loading a project more than once when it is repeated on the command
   --  line. Scenario_Vars holds "name=value" pairs collected from -X
   --  command-line switches and is applied the same way gprbuild's own -X
   --  switch overrides a scenario variable's project-file default or
   --  ambient environment-variable value.

end Adalang_Analyzer.Project_Files;
