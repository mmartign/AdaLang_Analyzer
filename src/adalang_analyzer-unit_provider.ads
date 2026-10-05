--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Langkit_Support.File_Readers;
with Libadalang.Analysis;

with Adalang_Analyzer.Project_Files;

--  Unit-provider composition used by the CLI: explicit/project source paths
--  take precedence, while unresolved units (notably the native runtime) fall
--  back to Libadalang's default provider.
private package Adalang_Analyzer.Unit_Provider is

   function Create
     (Primary  : Libadalang.Analysis.Unit_Provider_Reference;
      Fallback : Libadalang.Analysis.Unit_Provider_Reference)
      return Libadalang.Analysis.Unit_Provider_Reference;

   function Create_Preprocessed_Index
     (Files  : Project_Files.File_Name_Vectors.Vector;
      Reader : Langkit_Support.File_Readers.File_Reader_Reference)
      return Libadalang.Analysis.Unit_Provider_Reference;
   --  A provider for the compilation units of those of Files that hold
   --  preprocessor directives, read through Reader. Libadalang's own
   --  provider over a list of files reads them as they stand and leaves
   --  out the ones that do not parse, so the units of such a file could
   --  not be found from another unit. A null reference when Reader is null
   --  or no file holds a directive.

end Adalang_Analyzer.Unit_Provider;
