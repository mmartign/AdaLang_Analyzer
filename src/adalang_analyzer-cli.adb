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

with Ada.Characters.Latin_1;
with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib; use type GNAT.OS_Lib.String_Access;

with GNATCOLL.VFS;

with Libadalang.Analysis;
with Libadalang.Auto_Provider;
with Libadalang.Unit_Files;

with Adalang_Analyzer.Checks;
with Adalang_Analyzer.Circular_Dependencies;
with Adalang_Analyzer.Clone_Detection;
with Adalang_Analyzer.Compliance_Mapping;
with Adalang_Analyzer.Config;        use Adalang_Analyzer.Config;
with Adalang_Analyzer.Config_File;   use Adalang_Analyzer.Config_File;
with Adalang_Analyzer.Flow_Interp;
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.Project_Files; use Adalang_Analyzer.Project_Files;
with Adalang_Analyzer.Report;        use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;         use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Subprogram_Summaries;
with Adalang_Analyzer.Text_Utils;    use Adalang_Analyzer.Text_Utils;
with Adalang_Analyzer.VC_Prover;
with Adalang_Analyzer.Unit_Provider;

package body Adalang_Analyzer.CLI is

   use type Ada.Directories.File_Kind;

   Show_Help_Flag   : Boolean := False;
   Show_Version     : Boolean := False;
   List_Checks_Only : Boolean := False;
   Invalid_Options  : Boolean := False;
   Baseline_File    : Unbounded_String;
   Baseline_Output  : Unbounded_String;
   Report_Filename  : Unbounded_String;
   Report_Format    : Output_Format := Text_Output;
   Compliance_Report_Standard : Unbounded_String;
   Compliance_Report_Output  : Unbounded_String;
   Compliance_Report_Format  : Output_Format := Text_Output;
   Compliance_Report_Format_Set : Boolean := False;
   --  Whether --compliance-report-format was actually given, since its
   --  value alone can't distinguish "explicitly markdown" from "never
   --  touched" (both are Text_Output). Needed to catch
   --  --compliance-report-format/--compliance-report-output given without
   --  the --compliance-report=<standard> that makes them meaningful.

   function Normalized_File_Name (Name : String) return String is
   begin
      return Ada.Directories.Full_Name (Name);
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         --  Preserve invalid or inaccessible inputs so Process_File can emit
         --  its normal diagnostic. Exact repetitions are still collapsed.
         return Name;
   end Normalized_File_Name;

   procedure Deduplicate_Files (Files : in out File_Name_Vectors.Vector) is
      Unique_Files : File_Name_Vectors.Vector;
      Identities   : File_Name_Vectors.Vector;
   begin
      for Filename of Files loop
         declare
            Identity : constant String := Normalized_File_Name (Filename);
            Seen     : Boolean := False;
         begin
            for Existing of Identities loop
               if Existing = Identity then
                  Seen := True;
                  exit;  --  adalang-analyzer: ignore No_Exit
               end if;
            end loop;

            if not Seen then
               File_Name_Vectors.Append (Unique_Files, Filename);
               File_Name_Vectors.Append (Identities, Identity);
            end if;
         end;
      end loop;

      Files := Unique_Files;
   end Deduplicate_Files;

   --  Prints command-line usage for -h/--help and after an option error.
   procedure Show_Help is
   begin
      Ada.Text_IO.Put_Line ("Usage: adalang-analyzer [options] <source_files>");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line
        ("Static analysis and bounded verification for Ada, based on Libadalang.");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.Put_Line ("  -h, --help            Show this help and exit");
      Ada.Text_IO.Put_Line
        ("  -version, --version   Show version and exit");
      Ada.Text_IO.Put_Line ("  -P<project>.gpr       Analyze the sources of a GNAT project file");
      Ada.Text_IO.Put_Line ("  -X<name>=<value>      Set a project scenario variable (repeatable)");
      Ada.Text_IO.Put_Line ("  -checks=<list>        Enable/disable checks");
      Ada.Text_IO.Put_Line ("  -list-checks          List available checks");
      Ada.Text_IO.Put_Line
        ("  --recommended         Enable low-noise defect checks");
      Ada.Text_IO.Put_Line
        ("  --spark               Enable proof-focused SPARK checks");
      Ada.Text_IO.Put_Line
        ("  --verify              Run bounded scalar verification");
      Ada.Text_IO.Put_Line
        ("  --automotive          Enable automotive Ada restrictions");
      Ada.Text_IO.Put_Line
        ("  --do178c=<A|B|C|D>    Enable a DO-178C verification-support profile");
      Ada.Text_IO.Put_Line
        ("  --format=<text|json|sarif> Select report format (default: text)");
      Ada.Text_IO.Put_Line
        ("  --output=<file>       Write the report to a file");
      Ada.Text_IO.Put_Line
        ("  --baseline=<file>     Exclude matching fingerprinted findings");
      Ada.Text_IO.Put_Line
        ("  --write-baseline=<file> Write this run's finding fingerprints");
      Ada.Text_IO.Put_Line
        ("  --compliance-report=<standard>  Write a per-objective evidence " &
         "report ('do178c' or 'iso26262')");
      Ada.Text_IO.Put_Line
        ("  --compliance-report-output=<file>  Destination for " &
         "--compliance-report (default: stdout)");
      Ada.Text_IO.Put_Line
        ("  --compliance-report-format=<markdown|json>  Representation " &
         "for --compliance-report (default: markdown)");
      Ada.Text_IO.Put_Line
        ("  -complexity-threshold=<n>  Set complexity limit (default: 10)");
      Ada.Text_IO.Put_Line
        ("  -nesting-threshold=<n>     Set nesting depth limit (default: 4)");
      Ada.Text_IO.Put_Line
        ("  -parameter-threshold=<n>   Set parameter count limit (default: 6)");
      Ada.Text_IO.Put_Line
        ("  -line-length-threshold=<n> Set line length limit (default: 120)");
      Ada.Text_IO.Put_Line
        ("  -generic-threshold=<n> Set generic-instantiation limit (default: 10)");
      Ada.Text_IO.Put_Line
        ("  -dependency-threshold=<n> Set with-clause limit (default: 20)");
      Ada.Text_IO.Put_Line
        ("  -v, -verbose          Enable verbose output (required in text" &
         " format to list per-proof-obligation detail lines)");
      Ada.Text_IO.Put_Line ("  -q, -quiet            Suppress summary output");
      Ada.Text_IO.Put_Line
        ("  --config=<file>       Use this config file instead of " &
         Default_Config_File_Name);
      Ada.Text_IO.Put_Line
        ("  --no-config           Disable auto-discovery of " &
         Default_Config_File_Name);
      Ada.Text_IO.Put_Line ("  --                    Treat items as files");
   end Show_Help;

   --  Prints the tool's version for -version.
   procedure Print_Version is
   begin
      Ada.Text_IO.Put_Line ("adalang-analyzer version " & Analyzer_Version);
   end Print_Version;

   --  Prints every registered check with its description and remediation
   --  guidance, for -list-checks.
   procedure Print_Check_List is
   begin
      Ada.Text_IO.Put_Line ("Available checks:");
      for Rule in Rule_Kind loop
         Ada.Text_IO.Put_Line ("  " & To_String (Rule_Infos (Rule).Name) &
                               " [" & Quality_Name (Rule_Infos (Rule).Quality) & "/" &
                               Severity_Name (Rule_Infos (Rule).Severity) & "] - " &
                               To_String (Rule_Infos (Rule).Description));
         Ada.Text_IO.Put_Line ("    " &
                               To_String (Rule_Infos (Rule).Guidance));
      end loop;
   end Print_Check_List;

   procedure Set_Report_Format (Name : String) is
      Value : constant String :=
        Ada.Characters.Handling.To_Lower
          (Ada.Strings.Fixed.Trim (Name, Ada.Strings.Both));
   begin
      if Value = "text" then
         Report_Format := Text_Output;
      elsif Value = "json" then
         Report_Format := JSON_Output;
      elsif Value = "sarif" then
         Report_Format := SARIF_Output;
      else
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid report format '" & Name & "'");
         Invalid_Options := True;
      end if;
   end Set_Report_Format;

   --  Validates a --compliance-report value before recording it, so an
   --  unsupported standard fails the invocation instead of silently
   --  producing no report.
   procedure Set_Compliance_Report_Standard (Name : String) is
      Found : Boolean;
      Ignored_Kind : constant Adalang_Analyzer.Compliance_Mapping.Standard_Kind
        := Adalang_Analyzer.Compliance_Mapping.Lookup_Standard (Name, Found);
      pragma Unreferenced (Ignored_Kind);
   begin
      if Found then
         Compliance_Report_Standard := To_Unbounded_String (Name);
      else
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: unsupported compliance standard '" & Name &
            "' (supported: 'do178c', 'iso26262')");
         Invalid_Options := True;
      end if;
   end Set_Compliance_Report_Standard;

   --  Validates a --compliance-report-format value. SARIF is deliberately
   --  not offered here: SARIF's result-oriented schema has no natural slot
   --  for the objective/evidence structure this report is built around --
   --  use --format=sarif for a SARIF rendering of the underlying findings
   --  instead.
   procedure Set_Compliance_Report_Format (Name : String) is
      Value : constant String :=
        Ada.Characters.Handling.To_Lower
          (Ada.Strings.Fixed.Trim (Name, Ada.Strings.Both));
   begin
      Compliance_Report_Format_Set := True;
      if Value = "markdown" then
         Compliance_Report_Format := Text_Output;
      elsif Value = "json" then
         Compliance_Report_Format := JSON_Output;
      else
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid compliance report format '" & Name &
            "' (expected 'markdown' or 'json')");
         Invalid_Options := True;
      end if;
   end Set_Compliance_Report_Format;

   --  Applies a GCC-style "+R<check>" / "-R<check>" switch, enabling or
   --  disabling exactly the named check.
   procedure Process_Command_Switch (Switch : String) is
      procedure Apply (Name : String; Mode : Rule_State) is
         Found : Boolean := False;
         Kind  : Rule_Kind;
      begin
         Kind := Lookup_Rule_Kind (Name, Found);
         if Found then
            Rule_States (Kind) := Mode;
         else
            Ada.Text_IO.Put_Line ("adalang-analyzer: unknown check '" & Name & "'");
            Invalid_Options := True;
         end if;
      end Apply;
   begin
      if Switch'Length < 3 then  --  adalang-analyzer: ignore Magic_Number
         return;
      end if;

      if Switch (Switch'First) = '-' and then Switch (Switch'First + 1) = 'R' then
         Apply (Switch (Switch'First + 2 .. Switch'Last), Disabled);  --  adalang-analyzer: ignore Magic_Number
      elsif Switch (Switch'First) = '+' and then Switch (Switch'First + 1) = 'R' then
         Apply (Switch (Switch'First + 2 .. Switch'Last), Enabled);  --  adalang-analyzer: ignore Magic_Number
      end if;
   end Process_Command_Switch;

   --  Applies a "-checks=<list>" option: a comma-separated list of check
   --  names, each optionally prefixed with '+' (enable, the default) or
   --  '-' (disable), plus the special items "*" (enable all) and "-*"
   --  (disable all).
   procedure Parse_Checks_Option (Option : String) is
      List_Text : constant String := Option (Option'First + 8 .. Option'Last);

      --  Applies one comma-separated item from the -checks= list.
      procedure Apply_Check_Item (Item_Untrimmed : String) is
         Item   : constant String :=
           Ada.Strings.Fixed.Trim (Item_Untrimmed, Ada.Strings.Both);
         Kind   : Rule_Kind;
         Found  : Boolean := False;
         Action : Rule_State := Enabled;
         First  : Positive := Item'First;
      begin
         if Item = "" then
            null;  --  adalang-analyzer: ignore Null_Statement
         elsif Item = "*" then
            for R in Rule_Kind loop
               Rule_States (R) := Enabled;
            end loop;
         elsif Item = "-*" then
            for R in Rule_Kind loop
               Rule_States (R) := Disabled;
            end loop;
         else
            Action := Enabled;

            if Item (First) = '+' then
               First := First + 1;
            elsif Item (First) = '-' then
               Action := Disabled;
               First := First + 1;
            end if;

            if First > Item'Last then
               Ada.Text_IO.Put_Line ("adalang-analyzer: empty check name");
               Invalid_Options := True;
            else
               declare
                  Name : constant String := Item (First .. Item'Last);
               begin
                  Kind := Lookup_Rule_Kind (Name, Found);
                  if Found then
                     Rule_States (Kind) := Action;
                  else
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: unknown check '" & Name & "'");
                     Invalid_Options := True;
                  end if;
               end;
            end if;
         end if;
      end Apply_Check_Item;

      Start : Positive := List_Text'First;
   begin
      for Index in List_Text'Range loop
         if List_Text (Index) = ',' then
            Apply_Check_Item (List_Text (Start .. Index - 1));
            Start := Index + 1;
         end if;
      end loop;

      if Start <= List_Text'Last then
         Apply_Check_Item (List_Text (Start .. List_Text'Last));
      end if;
   end Parse_Checks_Option;

   --  Selects defect-oriented checks suitable for routine local and CI use.
   --  Deliberately excludes certification traceability, coding-style,
   --  restricted-construct, and mandatory-contract policy checks: those are
   --  valuable only when their corresponding project profile applies.
   procedure Enable_Recommended_Preset is
      Recommended_Rules : constant array (Positive range <>) of Rule_Kind :=
        (Unused_Parameter, Wrong_Parameter_Mode, Dead_Store,
         Overwritten_Assignment, Unreachable_Case_Alternative,
         Overlapping_Case_Ranges, Infinite_Loop, Duplicate_Boolean_Operand,
         Exception_Swallowed, Constant_Condition, Unreachable_Code,
         Division_By_Zero, Reversed_Range, Self_Assignment, Same_Operand,
         Duplicate_Condition, Empty_Exception_Handler, Unreachable_Branch,
         Contradictory_Condition, Identical_Branches, Repeated_Statement,
         Ineffective_Operation, Constant_Result_Operation, Empty_Loop,
         Unused_Variable, Empty_If_Body, Function_Side_Effect,
         Redundant_Boolean_Comparison, Uninitialized_Output,
         Uninitialized_Read, Known_Precondition_Failure,
         Known_Postcondition_Failure, Known_Assertion_Failure,
         Known_Range_Check_Failure, Known_Index_Check_Failure,
         Known_Overflow_Failure, Identical_Case_Alternative,
         Redundant_Type_Conversion, Handler_Order,
         Aliasing_Between_Parameters, Known_Discriminant_Check_Failure,
         Swappable_Parameters);
   begin
      Active_Preset := Recommended_Preset;
      Active_Assurance_Profile := No_Assurance_Profile;
      Verification_Mode := False;
      for Rule in Rule_Kind loop
         Rule_States (Rule) := Disabled;
      end loop;

      for Rule of Recommended_Rules loop
         Rule_States (Rule) := Enabled;
      end loop;
   end Enable_Recommended_Preset;

   --  Selects a compact set of checks that tend to block proof, obscure
   --  data dependencies, or leave the SPARK subset. Later command-line
   --  check switches can still refine this preset.
   procedure Enable_SPARK_Preset is
      SPARK_Rules : constant array (Positive range <>) of Rule_Kind :=
        (No_Goto, No_Abort, No_Raise, No_Access_To_Subp_Def,
         No_Unchecked_Conversion, Floating_Equality, Dead_Store,
         Overwritten_Assignment, Infinite_Loop, Constant_Condition,
         Unreachable_Code, Division_By_Zero, Reversed_Range,
         Self_Assignment, Contradictory_Condition, No_Recursion,
         Non_Short_Circuit_Condition, Address_Clause,
         Function_Side_Effect, SPARK_Mode,
         Missing_Global_Contract, Global_Contract_Mismatch,
         Missing_Depends_Contract, Incomplete_Depends_Contract,
         Depends_Contract_Mismatch, Uninitialized_Output,
         Known_Precondition_Failure, Known_Postcondition_Failure,
         Known_Assertion_Failure, Known_Range_Check_Failure,
         Known_Index_Check_Failure, Known_Overflow_Failure,
         Aliasing_Between_Parameters, Missing_Loop_Variant,
         Known_Discriminant_Check_Failure, Potentially_Blocking_Operation);
   begin
      Active_Preset := SPARK_Preset;
      Active_Assurance_Profile := No_Assurance_Profile;
      Verification_Mode := False;
      for Rule in Rule_Kind loop
         Rule_States (Rule) := Disabled;
      end loop;

      for Rule of SPARK_Rules loop
         Rule_States (Rule) := Enabled;
      end loop;
   end Enable_SPARK_Preset;

   procedure Enable_Verification_Preset is
   begin
      Enable_SPARK_Preset;
      Active_Preset := Verification_Preset;
      Verification_Mode := True;
   end Enable_Verification_Preset;

   procedure Enable_Automotive_Preset is
      Automotive_Rules : Rule_List renames Rules.Automotive_Rules;
   begin
      Active_Preset := Automotive_Preset;
      Active_Assurance_Profile := No_Assurance_Profile;
      Verification_Mode := False;
      for Rule in Rule_Kind loop
         Rule_States (Rule) := Disabled;
      end loop;
      for Rule of Automotive_Rules loop
         Rule_States (Rule) := Enabled;
      end loop;
   end Enable_Automotive_Preset;

   procedure Enable_DO_178C_Preset (Level_Text : String) is
      Core_Rules     : Rule_List renames DO_178C_Core_Rules;
      Level_C_Rules  : Rule_List renames DO_178C_Level_C_Rules;
      Level_AB_Rules : Rule_List renames DO_178C_Level_AB_Rules;
      Level : constant String :=
        Ada.Characters.Handling.To_Upper
          (Ada.Strings.Fixed.Trim (Level_Text, Ada.Strings.Both));

      procedure Enable (Rules : Rule_List) is
      begin
         for Rule of Rules loop
            Rule_States (Rule) := Enabled;
         end loop;
      end Enable;
   begin
      Verification_Mode := False;
      for Rule in Rule_Kind loop
         Rule_States (Rule) := Disabled;
      end loop;

      if Level = "A" then
         Active_Assurance_Profile := DO_178C_Level_A;
      elsif Level = "B" then
         Active_Assurance_Profile := DO_178C_Level_B;
      elsif Level = "C" then
         Active_Assurance_Profile := DO_178C_Level_C;
      elsif Level = "D" then
         Active_Assurance_Profile := DO_178C_Level_D;
      else
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid DO-178C level '" & Level_Text &
            "' (expected A, B, C, or D)");
         Invalid_Options := True;
         return;
      end if;

      Active_Preset := DO_178C_Preset;
      Enable (Core_Rules);
      if Active_Assurance_Profile in
        DO_178C_Level_A | DO_178C_Level_B | DO_178C_Level_C
      then
         Enable (Level_C_Rules);
      end if;
      if Active_Assurance_Profile in DO_178C_Level_A | DO_178C_Level_B then
         Enable (Level_AB_Rules);
      end if;
   end Enable_DO_178C_Preset;

   --  Parses the -complexity-threshold value; records an invalid-option
   --  error instead of raising when Text isn't a positive integer.
   procedure Set_Complexity_Threshold (Text : String) is
   begin
      Complexity_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid complexity threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Complexity_Threshold;

   --  Parses the -nesting-threshold value; records an invalid-option error
   --  instead of raising when Text isn't a positive integer.
   procedure Set_Nesting_Threshold (Text : String) is
   begin
      Nesting_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid nesting threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Nesting_Threshold;

   --  Parses the -parameter-threshold value; records an invalid-option
   --  error instead of raising when Text isn't a positive integer.
   procedure Set_Parameter_Threshold (Text : String) is
   begin
      Parameter_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid parameter threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Parameter_Threshold;

   --  Parses the -line-length-threshold value; records an invalid-option
   --  error instead of raising when Text isn't a positive integer.
   procedure Set_Line_Length_Threshold (Text : String) is
   begin
      Line_Length_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid line length threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Line_Length_Threshold;

   procedure Set_Generic_Threshold (Text : String) is
   begin
      Generic_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid generic threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Generic_Threshold;

   procedure Set_Dependency_Threshold (Text : String) is
   begin
      Dependency_Threshold := Positive'Value
        (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("adalang-analyzer: invalid dependency threshold '" & Text & "'");
         Invalid_Options := True;
   end Set_Dependency_Threshold;

   --  Runs the checks that scan Filename's raw source text one line at a
   --  time rather than the parsed AST.
   --  Running independently of Evaluate_Node lets these still report on a
   --  file that fails to parse. Any I/O failure is swallowed, same as
   --  Source_Line, since these checks are best-effort and must not abort
   --  analysis of the rest of the file.
   procedure Check_Line_Based_Rules (Filename : String) is
      File        : Ada.Text_IO.File_Type;
      Line_Number : Natural := 0;
   begin
      if Rule_States (Long_Line) /= Enabled
        and then Rule_States (Trailing_Whitespace) /= Enabled
        and then Rule_States (Malformed_Requirement_Trace) /= Enabled
        and then Rule_States (Suppression_Without_Rationale) /= Enabled
      then
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line       : constant String := Ada.Text_IO.Get_Line (File);
            Lower_Line : constant String :=
              Ada.Characters.Handling.To_Lower (Line);
            Comment_Position : constant Natural :=
              Ada.Strings.Fixed.Index (Lower_Line, "--");
            Requirement_Position : constant Natural :=
              Ada.Strings.Fixed.Index (Lower_Line, "do-178c: req");
            Suppression_Position : constant Natural :=
              Ada.Strings.Fixed.Index
                (Lower_Line, "adalang-analyzer: ignore");
         begin
            Line_Number := Line_Number + 1;

            if Rule_States (Long_Line) = Enabled
              and then Line'Length > Line_Length_Threshold
            then
               Report_Line_Violation
                 (Filename    => Filename,
                  Line_Number => Line_Number,
                  Column      => Line_Length_Threshold + 1,
                  Caret_Width => Line'Length - Line_Length_Threshold,
                  Rule        => Long_Line,
                  Message     => "line length " & To_Decimal (Line'Length) &
                    " exceeds threshold " & To_Decimal (Line_Length_Threshold));
            end if;

            if Rule_States (Trailing_Whitespace) = Enabled
              and then Line'Length > 0
              and then (Line (Line'Last) = ' '
                        or else Line (Line'Last) = Ada.Characters.Latin_1.HT)
            then
               declare
                  Trimmed_Length : constant Natural :=
                    Ada.Strings.Fixed.Trim (Line, Ada.Strings.Right)'Length;
               begin
                  Report_Line_Violation
                    (Filename    => Filename,
                     Line_Number => Line_Number,
                     Column      => Trimmed_Length + 1,
                     Caret_Width => Line'Length - Trimmed_Length,
                     Rule        => Trailing_Whitespace,
                     Message     => "line has trailing whitespace");
               end;
            end if;

            if Rule_States (Malformed_Requirement_Trace) = Enabled
              and then Comment_Position > 0
              and then Requirement_Position > Comment_Position
            then
               declare
                  First : constant Natural :=
                    Requirement_Position + String'("do-178c: req")'Length;
               begin
                  if First > Lower_Line'Last
                    or else Ada.Strings.Fixed.Trim
                      (Lower_Line (First .. Lower_Line'Last),
                       Ada.Strings.Both) = ""
                  then
                     Report_Line_Violation
                       (Filename    => Filename,
                        Line_Number => Line_Number,
                        Column      => Requirement_Position,
                        Caret_Width => String'("do-178c: req")'Length,
                        Rule        => Malformed_Requirement_Trace,
                        Message     =>
                          "DO-178C requirement trace has no identifier");
                  end if;
               end;
            end if;

            if Rule_States (Suppression_Without_Rationale) = Enabled
              and then Comment_Position > 0
              and then Suppression_Position > Comment_Position
              and then Ada.Strings.Fixed.Index
                (Lower_Line, "rationale:") = 0
            then
               Report_Line_Violation
                 (Filename    => Filename,
                  Line_Number => Line_Number,
                  Column      => Suppression_Position,
                  Caret_Width =>
                    String'("adalang-analyzer: ignore")'Length,
                  Rule        => Suppression_Without_Rationale,
                  Message     => "rule suppression has no rationale");
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
   end Check_Line_Based_Rules;

   --  Parses one file with Libadalang and, if it parsed cleanly, walks it
   --  with Evaluate_Node. Parse diagnostics are printed but do not stop
   --  the run; any other failure while processing this file is caught so
   --  one bad file can't abort analysis of the rest.
   procedure Process_File
     (Filename : String; Ctx : Libadalang.Analysis.Analysis_Context)
   is
      Unit : Libadalang.Analysis.Analysis_Unit;
   begin
      if not Ada.Directories.Exists (Filename) then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "adalang-analyzer: File not found: " & Filename);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      elsif Ada.Directories.Kind (Filename) /=
        Ada.Directories.Ordinary_File
      then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: not a regular source file: " & Filename);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Source_File_Count := Source_File_Count + 1;
      Record_Analyzed_File (Filename);
      Log_Verbose ("Parsing: " & Filename);

      Check_Line_Based_Rules (Filename);

      Unit := Ctx.Get_From_File (Filename);

      if Unit.Has_Diagnostics then
         for Diagnostic of Libadalang.Analysis.Diagnostics (Unit) loop
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               Libadalang.Analysis.Format_GNU_Diagnostic
                 (Unit, Diagnostic));
         end loop;
         --  A file that did not parse was not analyzed. Treating that as a
         --  successful, violation-free run would let malformed input pass a
         --  CI quality gate even though none of the AST checks ran.
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      else
         Checks.Evaluate_Node (Unit, Unit.Root);
         if Verification_Mode then
            Adalang_Analyzer.Flow_Interp.Verify_Unit (Unit);
         end if;
      end if;

   exception
      when Exc : others =>
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "Error processing " & Filename & ": " & Ada.Exceptions.Exception_Message (Exc));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Process_File;

   --  Best-effort fallback for the "gnatls" lookup below: when it is not on
   --  PATH, an Alire-managed toolchain may still be present locally (e.g.
   --  the binary was built with "alr build" but is now being run directly
   --  instead of via "alr exec --"). Reads Alire's own global settings to
   --  find the selected gnat toolchain and locates its bin/ directory under
   --  Alire's toolchain cache, without requiring "alr exec" to be used for
   --  every invocation. Returns "" if nothing can be found; the caller then
   --  falls back to the pre-existing warning, so a wrong guess here (e.g.
   --  the Windows paths, which are unverified) never regresses behavior.
   function Locate_Alire_Gnatls_Dir return String is
      function Env (Name : String) return String is
        (Ada.Environment_Variables.Value (Name, ""));

      --  Alire keeps its global settings under the XDG config directory
      --  (also the macOS default: confirmed against a live "alr" install),
      --  with an unverified best-effort guess at the Windows equivalent.
      function Settings_Path return String is
         Xdg  : constant String := Env ("XDG_CONFIG_HOME");
         Home : constant String := Env ("HOME");
         Ad   : constant String := Env ("APPDATA");
      begin
         if Xdg /= ""
           and then Ada.Directories.Exists (Xdg & "/alire/settings.toml")
         then
            return Xdg & "/alire/settings.toml";
         elsif Home /= ""
           and then Ada.Directories.Exists
                      (Home & "/.config/alire/settings.toml")
         then
            return Home & "/.config/alire/settings.toml";
         elsif Ad /= ""
           and then Ada.Directories.Exists (Ad & "\alire\settings.toml")
         then
            return Ad & "\alire\settings.toml";
         else
            return "";
         end if;
      end Settings_Path;

      function Toolchains_Dir return String is
         Xdg   : constant String := Env ("XDG_DATA_HOME");
         Home  : constant String := Env ("HOME");
         Local : constant String := Env ("LOCALAPPDATA");
      begin
         if Xdg /= ""
           and then Ada.Directories.Exists (Xdg & "/alire/toolchains")
         then
            return Xdg & "/alire/toolchains";
         elsif Home /= ""
           and then Ada.Directories.Exists
                      (Home & "/.local/share/alire/toolchains")
         then
            return Home & "/.local/share/alire/toolchains";
         elsif Local /= ""
           and then Ada.Directories.Exists (Local & "\alire\toolchains")
         then
            return Local & "\alire\toolchains";
         else
            return "";
         end if;
      end Toolchains_Dir;

      --  Parses the TOML "[toolchain.use]" section's "gnat = " entry (e.g.
      --  gnat = "gnat_native=16.1.0") into the directory-name prefix Alire
      --  uses for that toolchain's cache entry, e.g. "gnat_native_16.1.0_"
      --  (the trailing content-hash segment varies per machine, so only
      --  the prefix is matched).
      function Selected_Toolchain_Prefix return String is
         Path    : constant String := Settings_Path;
         File    : Ada.Text_IO.File_Type;
         Section : Ada.Strings.Unbounded.Unbounded_String;
      begin
         if Path = "" then
            return "";
         end if;

         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line : constant String :=
                 Ada.Strings.Fixed.Trim
                   (Ada.Text_IO.Get_Line (File), Ada.Strings.Both);
            begin
               if Line'Length >= 2
                 and then Line (Line'First) = '['
                 and then Line (Line'Last) = ']'
               then
                  Section :=
                    Ada.Strings.Unbounded.To_Unbounded_String
                      (Line (Line'First + 1 .. Line'Last - 1));
               elsif Ada.Strings.Unbounded.To_String (Section) =
                       "toolchain.use"
               then
                  declare
                     Eq : constant Natural :=
                       Ada.Strings.Fixed.Index (Line, "=");
                  begin
                     if Eq > 0
                       and then Ada.Strings.Fixed.Trim
                                  (Line (Line'First .. Eq - 1),
                                   Ada.Strings.Both) =
                                "gnat"
                     then
                        declare
                           Raw : constant String :=
                             Ada.Strings.Fixed.Trim
                               (Line (Eq + 1 .. Line'Last),
                                Ada.Strings.Both);
                           Value : constant String :=
                             (if Raw'Length >= 2
                                and then Raw (Raw'First) = '"'
                                and then Raw (Raw'Last) = '"'
                              then Raw (Raw'First + 1 .. Raw'Last - 1)
                              else Raw);
                           Inner_Eq : constant Natural :=
                             Ada.Strings.Fixed.Index (Value, "=");
                        begin
                           if Inner_Eq > 0 then
                              Ada.Text_IO.Close (File);
                              return
                                Value (Value'First .. Inner_Eq - 1) & "_" &
                                Value (Inner_Eq + 1 .. Value'Last) & "_";
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (File);
         return "";
      end Selected_Toolchain_Prefix;

      Prefix : constant String := Selected_Toolchain_Prefix;
      Base   : constant String := Toolchains_Dir;
      Exe    : constant String :=
        (if Env ("OS") = "Windows_NT" then "gnatls.exe" else "gnatls");
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      if Prefix = "" or else Base = "" then
         return "";
      end if;

      Ada.Directories.Start_Search
        (Search, Base, "",
         (Ada.Directories.Directory => True, others => False));
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name'Length > Prefix'Length
              and then Name (Name'First .. Name'First + Prefix'Length - 1) =
                         Prefix
            then
               declare
                  Bin_Dir : constant String :=
                    Ada.Directories.Full_Name (Item) & "/bin";
               begin
                  if Ada.Directories.Exists (Bin_Dir & "/" & Exe) then
                     Ada.Directories.End_Search (Search);
                     return Bin_Dir;
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      return "";
   exception
      when others =>
         return "";
   end Locate_Alire_Gnatls_Dir;

   procedure Run is
      Files_To_Process   : File_Name_Vectors.Vector;
      Project_Gpr_Files  : File_Name_Vectors.Vector;
      Seen_Projects      : File_Name_Vectors.Vector;
      Scenario_Vars      : File_Name_Vectors.Vector;
      Merged_Args        : File_Name_Vectors.Vector;
      Config_Token_Count : Natural := 0;
      Config_File_Path   : Unbounded_String := Null_Unbounded_String;
      Argument_Count     : Natural := 0;
      Current_Arg        : Natural := 1;
      Options_Ended      : Boolean := False;
      Ctx                : Libadalang.Analysis.Analysis_Context;
   begin
      --  Proof obligations have a run lifecycle independent from ordinary
      --  rule findings. No producer or reporter is connected yet, but reset
      --  the registry here so its ownership is explicit from the outset.
      Adalang_Analyzer.Proof_Obligations.Reset;

      --  Resolve an optional project configuration file before anything
      --  else. --config/--config=<file>/--no-config are pulled out of the
      --  real command line here (they are not recognized by the main
      --  switch loop below), and the config file's tokens -- if any -- are
      --  placed ahead of the remaining real arguments in Merged_Args. The
      --  main loop then simply scans Merged_Args left to right exactly as
      --  it always scanned Ada.Command_Line.Argument, so a real
      --  command-line flag naturally overrides whatever the config file
      --  set, by virtue of being processed second through the same mutable
      --  Config state -- no separate precedence logic is needed.
      declare
         Raw_Count   : constant Natural := Ada.Command_Line.Argument_Count;
         Raw_Index   : Natural := 1;
         Skip_Next   : Boolean := False;
         Config_Path : Unbounded_String := Null_Unbounded_String;
         No_Config   : Boolean := False;
         Real_Args   : File_Name_Vectors.Vector;
      begin
         while Raw_Index <= Raw_Count loop
            declare
               Raw_Arg : constant String :=
                 Ada.Command_Line.Argument (Raw_Index);
            begin
               if Skip_Next then
                  Skip_Next := False;
               elsif Raw_Arg = "--config" then
                  if Raw_Index = Raw_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected argument for --config");
                     Invalid_Options := True;
                  else
                     Config_Path := To_Unbounded_String
                       (Ada.Command_Line.Argument (Raw_Index + 1));
                     Skip_Next := True;
                  end if;
               elsif Raw_Arg'Length > 9
                 and then Ada.Strings.Fixed.Index
                   (Raw_Arg, "--config=") = Raw_Arg'First
               then
                  Config_Path :=
                    To_Unbounded_String (Raw_Arg (Raw_Arg'First + 9 .. Raw_Arg'Last));
               elsif Raw_Arg = "--no-config" then
                  No_Config := True;
               else
                  File_Name_Vectors.Append (Real_Args, Raw_Arg);
               end if;
            end;
            Raw_Index := Raw_Index + 1;
         end loop;

         if Config_Path /= Null_Unbounded_String and then No_Config then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "adalang-analyzer: --config and --no-config cannot be " &
               "combined");
            Invalid_Options := True;
         end if;

         if not Invalid_Options then
            declare
               Result : constant Config_File.Resolution :=
                 Config_File.Resolve (To_String (Config_Path), No_Config);
            begin
               if Result.Found then
                  Config_File_Path := Result.Path;
                  begin
                     Merged_Args :=
                       Config_File.Load_Tokens (To_String (Result.Path));
                  exception
                     when E : others =>
                        Ada.Text_IO.Put_Line
                          (Ada.Text_IO.Standard_Error,
                           "adalang-analyzer: could not load config file '" &
                           To_String (Result.Path) & "': " &
                           Ada.Exceptions.Exception_Message (E));
                        Ada.Command_Line.Set_Exit_Status
                          (Ada.Command_Line.Failure);
                        return;
                  end;
               elsif Config_Path /= Null_Unbounded_String then
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "adalang-analyzer: config file not found: " &
                     To_String (Config_Path));
                  Ada.Command_Line.Set_Exit_Status
                    (Ada.Command_Line.Failure);
                  return;
               end if;
            end;
         end if;

         Config_Token_Count := Natural (File_Name_Vectors.Length (Merged_Args));
         for A of Real_Args loop
            File_Name_Vectors.Append (Merged_Args, A);
         end loop;
      end;

      Argument_Count := Natural (File_Name_Vectors.Length (Merged_Args));

      --  Left-to-right scan of the command line: switches update the mode
      --  flags/rule states above, everything else (or anything after "--")
      --  is collected as either a project file (-P) or a source file name.
      while Current_Arg <= Argument_Count loop
         declare
            Arg : constant String :=
              File_Name_Vectors.Element (Merged_Args, Current_Arg);
         begin
            if not Options_Ended then
               if Arg = "--" then
                  Options_Ended := True;  --  adalang-analyzer: ignore Dead_Store
               elsif Arg = "-h" or else Arg = "--help" or else Arg = "-help" then
                  Show_Help_Flag := True;
               elsif Arg = "-version" or else Arg = "--version" then
                  Show_Version := True;
               elsif Arg = "-list-checks" or else Arg = "-list-rules" then
                  List_Checks_Only := True;
               elsif Arg = "--recommended" or else Arg = "-recommended" then
                  Enable_Recommended_Preset;
               elsif Arg = "--spark" or else Arg = "-spark" then
                  Enable_SPARK_Preset;
               elsif Arg = "--verify" or else Arg = "-verify" then
                  Enable_Verification_Preset;
               elsif Arg = "--automotive" or else Arg = "-automotive" then
                  Enable_Automotive_Preset;
               elsif Arg = "--do178c" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected level for --do178c");
                     Invalid_Options := True;
                  else
                     Enable_DO_178C_Preset
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 9
                 and then Ada.Strings.Fixed.Index
                   (Arg, "--do178c=") = Arg'First
               then
                  Enable_DO_178C_Preset
                    (Arg (Arg'First + 9 .. Arg'Last));
               elsif Arg = "--format" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected argument for --format");
                     Invalid_Options := True;
                  else
                     Set_Report_Format
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 9
                 and then Ada.Strings.Fixed.Index
                   (Arg, "--format=") = Arg'First
               then
                  Set_Report_Format
                    (Arg (Arg'First + 9 .. Arg'Last));
               elsif Arg = "--output" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected argument for --output");
                     Invalid_Options := True;
                  else
                     Report_Filename := To_Unbounded_String
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 9
                 and then Ada.Strings.Fixed.Index
                   (Arg, "--output=") = Arg'First
               then
                  Report_Filename :=
                    To_Unbounded_String (Arg (Arg'First + 9 .. Arg'Last));
               elsif Arg = "--baseline" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected argument for --baseline");
                     Invalid_Options := True;
                  else
                     Baseline_File := To_Unbounded_String
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 11
                 and then Ada.Strings.Fixed.Index
                   (Arg, "--baseline=") = Arg'First
               then
                  Baseline_File :=
                    To_Unbounded_String (Arg (Arg'First + 11 .. Arg'Last));
               elsif Arg = "--write-baseline" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected argument for --write-baseline");
                     Invalid_Options := True;
                  else
                     Baseline_Output := To_Unbounded_String
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 17
                 and then Ada.Strings.Fixed.Index
                   (Arg, "--write-baseline=") = Arg'First
               then
                  Baseline_Output :=
                    To_Unbounded_String (Arg (Arg'First + 17 .. Arg'Last));
               elsif Arg = "--compliance-report" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected argument for " &
                        "--compliance-report");
                     Invalid_Options := True;
                  else
                     Set_Compliance_Report_Standard
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 20
                 and then Ada.Strings.Fixed.Index
                   (Arg, "--compliance-report=") = Arg'First
               then
                  Set_Compliance_Report_Standard
                    (Arg (Arg'First + 20 .. Arg'Last));
               elsif Arg = "--compliance-report-output" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected argument for " &
                        "--compliance-report-output");
                     Invalid_Options := True;
                  else
                     Compliance_Report_Output := To_Unbounded_String
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 27
                 and then Ada.Strings.Fixed.Index
                   (Arg, "--compliance-report-output=") = Arg'First
               then
                  Compliance_Report_Output :=
                    To_Unbounded_String (Arg (Arg'First + 27 .. Arg'Last));
               elsif Arg = "--compliance-report-format" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected argument for " &
                        "--compliance-report-format");
                     Invalid_Options := True;
                  else
                     Set_Compliance_Report_Format
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 27
                 and then Ada.Strings.Fixed.Index
                   (Arg, "--compliance-report-format=") = Arg'First
               then
                  Set_Compliance_Report_Format
                    (Arg (Arg'First + 27 .. Arg'Last));
               elsif Arg = "-q" or else Arg = "-quiet" then
                  Quiet_Mode := True;
               elsif Arg = "-v" or else Arg = "-verbose" then
                  Verbose_Mode := True;  --  adalang-analyzer: ignore Dead_Store
               elsif Arg = "-checks" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line ("adalang-analyzer: expected argument for -checks");
                     Invalid_Options := True;
                  else
                     Parse_Checks_Option
                       ("-checks="
                        & File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 8
                 and then Arg (Arg'First .. Arg'First + 7) = "-checks="
               then
                  Parse_Checks_Option (Arg);
               elsif Arg = "-complexity-threshold" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected positive threshold value");
                     Invalid_Options := True;
                  else
                     Set_Complexity_Threshold
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 22  --  adalang-analyzer: ignore Magic_Number
                 and then Arg (Arg'First .. Arg'First + 21) =  --  adalang-analyzer: ignore Magic_Number
                   "-complexity-threshold="
               then
                  Set_Complexity_Threshold
                    (Arg (Arg'First + 22 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
               elsif Arg = "-nesting-threshold" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected positive threshold value");
                     Invalid_Options := True;
                  else
                     Set_Nesting_Threshold
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 19  --  adalang-analyzer: ignore Magic_Number
                 and then Arg (Arg'First .. Arg'First + 18) =  --  adalang-analyzer: ignore Magic_Number
                   "-nesting-threshold="
               then
                  Set_Nesting_Threshold
                    (Arg (Arg'First + 19 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
               elsif Arg = "-parameter-threshold" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected positive threshold value");
                     Invalid_Options := True;
                  else
                     Set_Parameter_Threshold
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 21  --  adalang-analyzer: ignore Magic_Number
                 and then Arg (Arg'First .. Arg'First + 20) =  --  adalang-analyzer: ignore Magic_Number
                   "-parameter-threshold="
               then
                  Set_Parameter_Threshold
                    (Arg (Arg'First + 21 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
               elsif Arg = "-line-length-threshold" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected positive threshold value");
                     Invalid_Options := True;
                  else
                     Set_Line_Length_Threshold
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 23  --  adalang-analyzer: ignore Magic_Number
                 and then Arg (Arg'First .. Arg'First + 22) =  --  adalang-analyzer: ignore Magic_Number
                   "-line-length-threshold="
               then
                  Set_Line_Length_Threshold
                    (Arg (Arg'First + 23 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
               elsif Arg = "-generic-threshold" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected positive threshold value");
                     Invalid_Options := True;
                  else
                     Set_Generic_Threshold
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 19
                 and then Arg (Arg'First .. Arg'First + 18) =
                   "-generic-threshold="
               then
                  Set_Generic_Threshold
                    (Arg (Arg'First + 19 .. Arg'Last));
               elsif Arg = "-dependency-threshold" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected positive threshold value");
                     Invalid_Options := True;
                  else
                     Set_Dependency_Threshold
                       (File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 22
                 and then Arg (Arg'First .. Arg'First + 21) =
                   "-dependency-threshold="
               then
                  Set_Dependency_Threshold
                    (Arg (Arg'First + 22 .. Arg'Last));
               elsif Arg = "-P" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line ("adalang-analyzer: expected argument for -P");
                     Invalid_Options := True;
                  else
                     File_Name_Vectors.Append
                       (Project_Gpr_Files,
                        File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 2
                 and then Arg (Arg'First .. Arg'First + 1) = "-P"
               then
                  File_Name_Vectors.Append
                    (Project_Gpr_Files, Arg (Arg'First + 2 .. Arg'Last));
               elsif Arg = "-X" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line ("adalang-analyzer: expected argument for -X");
                     Invalid_Options := True;
                  else
                     File_Name_Vectors.Append
                       (Scenario_Vars,
                        File_Name_Vectors.Element (Merged_Args, Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 2
                 and then Arg (Arg'First .. Arg'First + 1) = "-X"
               then
                  File_Name_Vectors.Append
                    (Scenario_Vars, Arg (Arg'First + 2 .. Arg'Last));
               elsif Arg (Arg'First) = '+' or else Arg (Arg'First) = '-' then
                  if Arg'Length > 2 and then Arg (Arg'First + 1) = 'R' then  --  adalang-analyzer: ignore Magic_Number
                     Process_Command_Switch (Arg);
                  else
                     Ada.Text_IO.Put_Line ("adalang-analyzer: unknown option '" & Arg & "'");
                     Invalid_Options := True;
                  end if;
               else
                  File_Name_Vectors.Append (Files_To_Process, Arg);
               end if;
            else
               File_Name_Vectors.Append (Files_To_Process, Arg);
            end if;
         end;
         Current_Arg := Current_Arg + 1;  --  adalang-analyzer: ignore Dead_Store
      end loop;

      --  --compliance-report-output and --compliance-report-format only do
      --  anything paired with --compliance-report=<standard>; given alone,
      --  they would otherwise be silently ignored -- the run analyzes the
      --  source normally and no compliance report, and no diagnostic about
      --  one, ever appears.
      if Compliance_Report_Standard = Null_Unbounded_String then
         if Compliance_Report_Output /= Null_Unbounded_String then
            Ada.Text_IO.Put_Line
              ("adalang-analyzer: --compliance-report-output was given " &
               "without --compliance-report=<standard>; no compliance " &
               "report would be written");
            Invalid_Options := True;
         elsif Compliance_Report_Format_Set then
            Ada.Text_IO.Put_Line
              ("adalang-analyzer: --compliance-report-format was given " &
               "without --compliance-report=<standard>; no compliance " &
               "report would be written");
            Invalid_Options := True;
         end if;
      end if;

      if Show_Help_Flag then
         Show_Help;
         return;
      elsif Show_Version then
         Print_Version;
         return;
      elsif Invalid_Options then
         if Config_Token_Count > 0 then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "adalang-analyzer: note: " &
               Ada.Strings.Fixed.Trim
                 (Config_Token_Count'Image, Ada.Strings.Left) &
               " of the above arguments were expanded from config file '" &
               To_String (Config_File_Path) & "'");
         end if;
         Show_Help;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      elsif List_Checks_Only then
         Print_Check_List;
         return;
      end if;

      declare
         Any_Check_Enabled : Boolean := False;
      begin
         for Rule in Rule_Kind loop
            if Rule_States (Rule) = Enabled then
               Any_Check_Enabled := True;
               exit;  --  adalang-analyzer: ignore No_Exit
            end if;
         end loop;

         --  A run with no active check always finds zero violations and
         --  exits successfully, which reads as "all clear" rather than
         --  "nothing was actually checked". Warning here (rather than
         --  failing outright: --do178c=<level> combined with -checks='-*'
         --  is a legitimate way to record assurance-profile metadata
         --  without running any check) turns a misconfigured invocation
         --  (e.g. a missing -checks= or preset flag in a CI script) from
         --  silent into visible, without breaking that metadata-only use.
         if not Any_Check_Enabled then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "adalang-analyzer: warning: no checks are enabled; pass " &
               "-checks=<list>, --recommended, --spark, --verify, " &
               "--automotive, or --do178c=<level> to actually analyze " &
               "the source");
         end if;
      end;

      --  Both the -P and project-less paths resolve with'd units (Interfaces,
      --  Ada.*, System, ...) through Libadalang.Unit_Files.Default_Provider,
      --  which in turn asks GNATCOLL.Projects to run "gnatls -v" to locate
      --  the default runtime's predefined source path; -P only contributes
      --  the project's own source list; it does not feed the project's
      --  runtime into this lookup. Without a "gnatls" on PATH, that lookup
      --  finds nothing, so any with'd runtime package is entirely
      --  unresolved -- which reliably (not just occasionally) trips a
      --  Libadalang defect deep in privacy/type resolution for subtypes of
      --  such packages (see known_analysis_issues.tsv, FP-029), silently
      --  degrading the affected checks instead of merely losing precision.
      --  Warning here turns a missing-toolchain environment from a quiet,
      --  scattered coverage gap into something the user can actually fix.
      declare
         Gnatls : GNAT.OS_Lib.String_Access :=
           GNAT.OS_Lib.Locate_Exec_On_Path ("gnatls");
      begin
         if Gnatls = null then
            declare
               Alire_Bin : constant String := Locate_Alire_Gnatls_Dir;
            begin
               if Alire_Bin /= "" then
                  Ada.Environment_Variables.Set
                    ("PATH",
                     Alire_Bin & GNAT.OS_Lib.Path_Separator &
                     Ada.Environment_Variables.Value ("PATH", ""));
                  Gnatls := GNAT.OS_Lib.Locate_Exec_On_Path ("gnatls");
               end if;
            end;
         end if;

         if Gnatls = null then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "adalang-analyzer: warning: no 'gnatls' found on PATH; " &
               "types from with'd runtime packages (Interfaces, Ada.*, " &
               "System, ...) will not resolve, which silently degrades " &
               "some checks (see known_analysis_issues.tsv, FP-029); add " &
               "a GNAT toolchain to PATH to avoid this");
         else
            GNAT.OS_Lib.Free (Gnatls);
         end if;
      end;

      if Report_Format = Text_Output
        and then Report_Filename /= Null_Unbounded_String
      then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: --output requires --format=json or sarif");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Set_Output (Report_Format, To_String (Report_Filename));
      Set_Configuration_Files
        (Config_Path   => To_String (Config_File_Path),
         Baseline_Path => To_String (Baseline_File));
      for P of Project_Gpr_Files loop
         Record_Project_File (P);
      end loop;
      for Scenario of Scenario_Vars loop
         Record_Scenario_Variable (Scenario);
      end loop;

      if Baseline_File /= Null_Unbounded_String then
         begin
            Load_Baseline (To_String (Baseline_File));
         exception
            when E : others =>
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "adalang-analyzer: could not load baseline '" &
                  To_String (Baseline_File) & "': " &
                  Ada.Exceptions.Exception_Message (E));
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
         end;
      end if;

      --  Project files contribute their own Ada sources on top of any file
      --  names given directly on the command line.
      for P of Project_Gpr_Files loop
         Load_Project_File (P, Files_To_Process, Seen_Projects, Scenario_Vars);
      end loop;

      --  A source may be named repeatedly, through path aliases, or both
      --  explicitly and by a project. Analyze each normalized input once.
      Deduplicate_Files (Files_To_Process);

      if File_Name_Vectors.Is_Empty (Files_To_Process) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: error: no source files provided.");
         Show_Help;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      --  Build semantic unit lookup from the complete source set.  The
      --  default Libadalang provider derives unit filenames relative to the
      --  process working directory, so a package body passed as
      --  "../sources/foo.adb" cannot otherwise find its sibling foo.ads.
      --  The auto provider records the actual paths supplied directly or
      --  discovered through -P, making semantic checks independent of where
      --  the analyzer was launched.
      declare
         Input_Files : GNATCOLL.VFS.File_Array
           (File_Name_Vectors.First_Index (Files_To_Process) ..
              File_Name_Vectors.Last_Index (Files_To_Process));
      begin
         for Index in Input_Files'Range loop
            Input_Files (Index) := GNATCOLL.VFS.Create_From_UTF8
              (File_Name_Vectors.Element (Files_To_Process, Index),
               Normalize => True);
         end loop;

         --  Summary discovery deliberately uses a separate context. Semantic
         --  property failures are memoized by Libadalang; isolating this
         --  speculative whole-input pass prevents one failed summary query
         --  from changing which ordinary checks later run in the main
         --  context.
         declare
            Summary_Ctx : constant Libadalang.Analysis.Analysis_Context :=
              Libadalang.Analysis.Create_Context
                (Unit_Provider =>
                   Adalang_Analyzer.Unit_Provider.Create
                     (Primary =>
                        Libadalang.Auto_Provider
                          .Create_Auto_Provider_Reference (Input_Files),
                      Fallback =>
                        Libadalang.Unit_Files.Default_Provider));
         begin
            Adalang_Analyzer.Subprogram_Summaries.Reset;
            for F of Files_To_Process loop
               Adalang_Analyzer.Subprogram_Summaries.Scan_Unit
                 (Summary_Ctx.Get_From_File (F));
            end loop;
            Adalang_Analyzer.Subprogram_Summaries.Complete;
         end;

         Ctx := Libadalang.Analysis.Create_Context
           (Unit_Provider =>
              Adalang_Analyzer.Unit_Provider.Create
                (Primary =>
                   Libadalang.Auto_Provider.Create_Auto_Provider_Reference
                     (Input_Files),
                 Fallback => Libadalang.Unit_Files.Default_Provider));
      end;

      Log_Verbose
        ("Built " &
         To_Decimal (Adalang_Analyzer.Subprogram_Summaries.Count) &
         " subprogram summaries");

      for F of Files_To_Process loop
         Process_File (F, Ctx);
      end loop;

      if Rule_States (Circular_Package_Dependency) = Enabled then
         Adalang_Analyzer.Circular_Dependencies.Analyze
           (Ctx, Files_To_Process);
      end if;

      if Rule_States (Duplicate_Subprogram) = Enabled then
         Adalang_Analyzer.Clone_Detection.Analyze (Ctx, Files_To_Process);
      end if;

      Finalize_Output;

      if Baseline_Output /= Null_Unbounded_String then
         Write_Baseline (To_String (Baseline_Output));
      end if;

      if Compliance_Report_Standard /= Null_Unbounded_String then
         Write_Compliance_Report
           (To_String (Compliance_Report_Standard),
            To_String (Compliance_Report_Output),
            Compliance_Report_Format);
      end if;

      if Selected_Output_Format = Text_Output and then not Quiet_Mode then
         Ada.Text_IO.New_Line;
         if Active_Assurance_Profile /= No_Assurance_Profile then
            Ada.Text_IO.Put_Line
              ("Assurance profile: " & Assurance_Profile_Name);
            Ada.Text_IO.Put_Line
              ("Coverage objective: " & Structural_Coverage_Objective &
               " (external evidence required)");
            Ada.Text_IO.Put_Line
              ("Certification claim: verification support only");
         end if;
         Ada.Text_IO.Put_Line ("Files scanned : " & To_Decimal (Source_File_Count));
         Ada.Text_IO.Put_Line ("Violations    : " & To_Decimal (Violations));

         if Adalang_Analyzer.Proof_Obligations.Count > 0 then
            Ada.Text_IO.Put_Line ("");
            Ada.Text_IO.Put_Line
              ("Proof obligations (" &
               Adalang_Analyzer.Proof_Obligations.Scope_Description & "):");
            Ada.Text_IO.Put_Line
              ("  Total : " &
               To_Decimal (Adalang_Analyzer.Proof_Obligations.Count));
            for Status in
              Adalang_Analyzer.Proof_Obligations.Obligation_Status
            loop
               declare
                  Status_Count : constant Natural :=
                    Adalang_Analyzer.Proof_Obligations.Count (Status);
               begin
                  if Status_Count > 0 then
                     Ada.Text_IO.Put_Line
                       ("  " &
                        Adalang_Analyzer.Proof_Obligations.Status_Name
                          (Status) &
                        " : " & To_Decimal (Status_Count));
                  end if;
               end;
            end loop;

            if Verbose_Mode then
               Ada.Text_IO.Put_Line ("  Details:");
               for Index in
                 1 .. Adalang_Analyzer.Proof_Obligations.Count
               loop
                  declare
                     package Proof renames
                       Adalang_Analyzer.Proof_Obligations;
                     Item : constant Proof.Obligation :=
                       Proof.Element (Index);
                  begin
                     Ada.Text_IO.Put_Line
                       ("    " & To_String (Item.Location.Filename) & ":" &
                        To_Decimal (Item.Location.Line) & ":" &
                        To_Decimal (Item.Location.Column) & " [" &
                        Proof.Kind_Name (Item.Kind) & "] " &
                        Proof.Status_Name (Item.Status));
                     Ada.Text_IO.Put_Line
                       ("      method: " & Proof.Method_Name (Item.Method));
                     if Item.Explanation /= Null_Unbounded_String then
                        Ada.Text_IO.Put_Line
                          ("      why: " & To_String (Item.Explanation));
                     end if;
                     if Item.Abstract_State /= Null_Unbounded_String then
                        Ada.Text_IO.Put_Line
                          ("      evidence: " &
                           To_String (Item.Abstract_State));
                     end if;
                     if Item.Imprecision_Source /= Null_Unbounded_String then
                        Ada.Text_IO.Put_Line
                          ("      imprecision: " &
                           To_String (Item.Imprecision_Source));
                     end if;
                     if Item.Reason_Code /= Null_Unbounded_String then
                        Ada.Text_IO.Put_Line
                          ("      reason: " & To_String (Item.Reason_Code));
                     end if;
                     if Item.Blocking_Expression /= Null_Unbounded_String then
                        Ada.Text_IO.Put_Line
                          ("      blocked at: " &
                           To_String (Item.Blocking_Expression));
                     end if;
                     if Item.Inline_Path /= Null_Unbounded_String then
                        Ada.Text_IO.Put_Line
                          ("      inline path: " &
                           To_String (Item.Inline_Path));
                     end if;
                  end;
               end loop;
            else
               Ada.Text_IO.Put_Line
                 ("  (details suppressed; rerun with -v to list each" &
                  " proof obligation)");
            end if;
         end if;

         if Baseline_Matches > 0 then
            Ada.Text_IO.Put_Line
              ("Baseline matches: " & To_Decimal (Baseline_Matches));
         end if;

         if Skipped_Nodes > 0 then
            --  Surfaced even without -verbose: a nonzero count here means
            --  checks were silently incomplete at some source locations, not
            --  just noisy diagnostics, so it belongs in the default summary.
            Ada.Text_IO.Put_Line
              ("Skipped checks: " & To_Decimal (Skipped_Nodes) &
               " location(s) (semantic resolution limits; rerun with -v for" &
               " details)");
         end if;

         if Violations > 0 then
            Ada.Text_IO.Put_Line ("");
            Ada.Text_IO.Put_Line ("Violations by check:");

            for Rule in Rule_Kind loop
               if Rule_Violations (Rule) > 0 then
                  Ada.Text_IO.Put_Line
                    ("  " & To_String (Rule_Infos (Rule).Name) &
                     " : " & To_Decimal (Rule_Violations (Rule)) & "  [" &
                     Quality_Name (Rule_Infos (Rule).Quality) & "/" &
                     Severity_Name (Rule_Infos (Rule).Severity) & "]");
               end if;
            end loop;

            Ada.Text_IO.Put_Line ("");
            Ada.Text_IO.Put_Line ("Violations by software quality:");

            for Quality in Software_Quality loop
               declare
                  Quality_Total : Natural := 0;
               begin
                  for Rule in Rule_Kind loop
                     if Rule_Infos (Rule).Quality = Quality then
                        Quality_Total := Quality_Total + Rule_Violations (Rule);
                     end if;
                  end loop;

                  if Quality_Total > 0 then
                     Ada.Text_IO.Put_Line
                       ("  " & Quality_Name (Quality) & " : " &
                        To_Decimal (Quality_Total));
                  end if;
               end;
            end loop;

            Ada.Text_IO.Put_Line ("");
            Ada.Text_IO.Put_Line ("Violations by severity:");

            for Severity in Issue_Severity loop
               declare
                  Severity_Total : Natural := 0;
               begin
                  for Rule in Rule_Kind loop
                     if Rule_Infos (Rule).Severity = Severity then
                        Severity_Total := Severity_Total + Rule_Violations (Rule);
                     end if;
                  end loop;

                  if Severity_Total > 0 then
                     Ada.Text_IO.Put_Line
                       ("  " & Severity_Name (Severity) & " : " &
                        To_Decimal (Severity_Total));
                  end if;
               end;
            end loop;
         end if;
      end if;

      if Violations > 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;

      Adalang_Analyzer.VC_Prover.Dump_Symbolic_Diagnostics;

   exception
      when E : others =>
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "Internal error: " & Ada.Exceptions.Exception_Information (E));
         Ada.Command_Line.Set_Exit_Status (2);  --  adalang-analyzer: ignore Magic_Number
   end Run;

end Adalang_Analyzer.CLI;
