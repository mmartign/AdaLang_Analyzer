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

with Ada.Exceptions;

with Adalang_Analyzer.Rules;

--  Runtime configuration shared across the whole run: which checks are
--  enabled, the configurable thresholds, and the verbosity flags. Kept
--  separate from Adalang_Analyzer.Rules (the static check registry) so
--  that registry stays a pure, stateless constant table.
package Adalang_Analyzer.Config is

   Analyzer_Version : constant String := "1.8.3";

   type Rule_State is (Disabled, Enabled);
   type Preset_Kind is
     (No_Preset, Recommended_Preset, SPARK_Preset, Verification_Preset,
      Automotive_Preset, DO_178C_Preset);
   type Assurance_Profile is
     (No_Assurance_Profile, DO_178C_Level_A, DO_178C_Level_B,
      DO_178C_Level_C, DO_178C_Level_D);

   Rule_States : array (Rules.Rule_Kind) of Rule_State :=
     (others => Disabled);

   Active_Preset : Preset_Kind := No_Preset;
   Active_Assurance_Profile : Assurance_Profile := No_Assurance_Profile;
   Verification_Mode : Boolean := False;
   --  Enables the bounded CFG/fixed-point verifier. This is intentionally
   --  separate from --spark, which remains a readiness/finding preset.

   Verbose_Mode : Boolean := False;
   Quiet_Mode   : Boolean := False;
   Default_Complexity_Threshold  : constant Positive := 10;
   Default_Nesting_Threshold     : constant Positive := 4;
   Default_Parameter_Threshold   : constant Positive := 6;
   Default_Line_Length_Threshold : constant Positive := 120;
   Default_Generic_Threshold     : constant Positive := 10;
   Default_Dependency_Threshold  : constant Positive := 20;

   Complexity_Threshold  : Positive := Default_Complexity_Threshold;
   Nesting_Threshold     : Positive := Default_Nesting_Threshold;
   Parameter_Threshold   : Positive := Default_Parameter_Threshold;
   Line_Length_Threshold : Positive := Default_Line_Length_Threshold;
   Generic_Threshold     : Positive := Default_Generic_Threshold;
   Dependency_Threshold  : Positive := Default_Dependency_Threshold;

   procedure Set_Rule_Parameter
     (Rule : Rules.Rule_Kind; Name : String; Value : String);
   --  Records a named parameter of one check, as given by
   --  "-rule-param=<check>.<name>=<value>". Name is case-insensitive; a
   --  later value for the same check and name replaces the earlier one.

   function Rule_Parameter
     (Rule : Rules.Rule_Kind; Name : String; Default : String) return String;
   function Rule_Parameter
     (Rule : Rules.Rule_Kind; Name : String; Default : Natural) return Natural;
   --  The parameter's recorded value, or Default when none was given (or,
   --  for the numeric form, when the recorded text is not a number).

   procedure Log_Verbose (Message : String);
   --  Prints a diagnostic line when Verbose_Mode is set and Quiet_Mode isn't.

   procedure Log_Verbose_Once (Message : String);
   --  Prints one occurrence of a recoverable semantic diagnostic. Libadalang
   --  can propagate the same memoized resolution failure through many
   --  dependent property queries; those repetitions add no new information.

   procedure Report_Recoverable_Failure_Once
     (Rule       : String;
      Operation  : String;
      Source     : String;
      Occurrence : Ada.Exceptions.Exception_Occurrence);
   --  Emits an always-visible warning for an internal analysis failure that
   --  was handled with a conservative fallback. Identical warnings are
   --  collapsed so one failing semantic property cannot flood stderr.

   function Assurance_Profile_Name return String;
   --  Stable human-readable name included in structured evidence.

   function Preset_Name return String;
   --  Stable command-line preset identifier included in structured evidence.

   function Structural_Coverage_Objective return String;
   --  Coverage objective associated with the selected DO-178C level. This is
   --  metadata only: AdaLang Analyzer does not itself measure test coverage.

end Adalang_Analyzer.Config;
