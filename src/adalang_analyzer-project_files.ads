--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Vectors;

--  Minimal GNAT project (.gpr) file support: a best-effort reader, not a
--  GPR language implementation. It recognizes the literal forms
--  "for <Attribute> use <value>;" and "extends <string>" by lexical
--  scanning, and ignores everything else (scenario variables, case
--  statements, package sections, "with" imports of other projects). It
--  supports exactly the attributes needed to discover Ada source files:
--  Source_Dirs, Source_Files, Excluded_Source_Files /
--  Locally_Removed_Files, and project extension via "extends". The GPR
--  lexer, directory walk, and path helpers behind Load_Project_File are
--  private implementation details, not part of this package's public
--  surface.
package Adalang_Analyzer.Project_Files is

   package File_Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   procedure Load_Project_File
     (Project_File : String;
      Files        : in out File_Name_Vectors.Vector;
      Seen         : in out File_Name_Vectors.Vector);
   --  Reads Project_File (appending ".gpr" if omitted) and appends the Ada
   --  sources it declares to Files, in extension order (a child project's
   --  own sources override same-named files inherited from a project it
   --  extends). Seen guards against cycles and repeat work when the same
   --  project is reached through more than one path.

end Adalang_Analyzer.Project_Files;
