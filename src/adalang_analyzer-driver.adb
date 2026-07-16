--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Adalang_Analyzer.CLI;

--  Program entry point. All behavior lives in Adalang_Analyzer.CLI.Run;
--  this procedure exists only because the executable needs a Main.
procedure Adalang_Analyzer.Driver is
begin
   Adalang_Analyzer.CLI.Run;
end Adalang_Analyzer.Driver;
