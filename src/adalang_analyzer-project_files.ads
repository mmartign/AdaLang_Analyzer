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
   --  the visible Ada sources of its root project to Files; the sources
   --  of the projects it imports are recorded for Imported_Sources. Seen avoids
   --  loading a project more than once when it is repeated on the command
   --  line. Scenario_Vars holds "name=value" pairs collected from -X
   --  command-line switches and is applied the same way gprbuild's own -X
   --  switch overrides a scenario variable's project-file default or
   --  ambient environment-variable value.

   function Lookup_Sources
     (Files : File_Name_Vectors.Vector) return File_Name_Vectors.Vector;
   --  Files followed by the Ada sources of the projects that the loaded
   --  projects import, directly or not (the run-time library aside). The
   --  added sources are not analyzed: they are there so that names in the
   --  analyzed sources that denote entities of an imported project can be
   --  resolved. A source whose file name Files already holds is not added.

   function Under_Project_SPARK_Mode (Filename : String) return Boolean;
   --  True when Filename is a source of a loaded project whose
   --  configuration pragmas (Compiler'Local_Configuration_Pragmas or
   --  Builder'Global_Configuration_Pragmas) contain "pragma SPARK_Mode;" or
   --  "pragma SPARK_Mode (On);". Such a source is in SPARK unless it says
   --  otherwise itself.

end Adalang_Analyzer.Project_Files;
