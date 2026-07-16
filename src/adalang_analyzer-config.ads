--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Adalang_Analyzer.Rules;

--  Runtime configuration shared across the whole run: which checks are
--  enabled, the configurable thresholds, and the verbosity flags. Kept
--  separate from Adalang_Analyzer.Rules (the static check registry) so
--  that registry stays a pure, stateless constant table.
package Adalang_Analyzer.Config is

   type Rule_State is (Disabled, Enabled);

   Rule_States : array (Rules.Rule_Kind) of Rule_State :=
     (others => Disabled);

   Verbose_Mode : Boolean := False;
   Quiet_Mode   : Boolean := False;

   Default_Complexity_Threshold  : constant Positive := 10;
   Default_Nesting_Threshold     : constant Positive := 4;
   Default_Parameter_Threshold   : constant Positive := 6;
   Default_Line_Length_Threshold : constant Positive := 120;

   Complexity_Threshold  : Positive := Default_Complexity_Threshold;
   Nesting_Threshold     : Positive := Default_Nesting_Threshold;
   Parameter_Threshold   : Positive := Default_Parameter_Threshold;
   Line_Length_Threshold : Positive := Default_Line_Length_Threshold;

   procedure Log_Verbose (Message : String);
   --  Prints a diagnostic line when Verbose_Mode is set and Quiet_Mode
   --  isn't.

end Adalang_Analyzer.Config;
