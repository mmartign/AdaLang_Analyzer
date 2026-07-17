--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Unit-provider composition used by the CLI: explicit/project source paths
--  take precedence, while unresolved units (notably the native runtime) fall
--  back to Libadalang's default provider.
private package Adalang_Analyzer.Unit_Provider is

   function Create
     (Primary  : Libadalang.Analysis.Unit_Provider_Reference;
      Fallback : Libadalang.Analysis.Unit_Provider_Reference)
      return Libadalang.Analysis.Unit_Provider_Reference;

end Adalang_Analyzer.Unit_Provider;
