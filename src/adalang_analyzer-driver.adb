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

with Adalang_Analyzer.CLI;

--  Program entry point. All behavior lives in Adalang_Analyzer.CLI.Run;
--  this procedure exists only because the executable needs a Main.
procedure Adalang_Analyzer.Driver is
begin
   Adalang_Analyzer.CLI.Run;
end Adalang_Analyzer.Driver;
