--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNATCOLL.VFS;

with Libadalang.Analysis;
with Libadalang.Auto_Provider;
with Libadalang.Unit_Files;

with Adalang_Analyzer.Checks;
with Adalang_Analyzer.Config;        use Adalang_Analyzer.Config;
with Adalang_Analyzer.Project_Files; use Adalang_Analyzer.Project_Files;
with Adalang_Analyzer.Report;        use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;         use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils;    use Adalang_Analyzer.Text_Utils;
with Adalang_Analyzer.Unit_Provider;

package body Adalang_Analyzer.CLI is

   Show_Help_Flag   : Boolean := False;
   Show_Version     : Boolean := False;
   List_Checks_Only : Boolean := False;
   Invalid_Options  : Boolean := False;

   --  Prints command-line usage for -h/--help and after an option error.
   procedure Show_Help is
   begin
      Ada.Text_IO.Put_Line ("Usage: adalang-analyzer [options] <source_files>");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("A clang-tidy analyzer for Ada based on Libadalang.");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.Put_Line ("  -h, --help            Show this help and exit");
      Ada.Text_IO.Put_Line ("  -version              Show version and exit");
      Ada.Text_IO.Put_Line ("  -P<project>.gpr       Analyze the sources of a GNAT project file");
      Ada.Text_IO.Put_Line ("  -checks=<list>        Enable/disable checks");
      Ada.Text_IO.Put_Line ("  -list-checks          List available checks");
      Ada.Text_IO.Put_Line
        ("  --spark               Enable proof-focused SPARK checks");
      Ada.Text_IO.Put_Line
        ("  -complexity-threshold=<n>  Set complexity limit (default: 10)");
      Ada.Text_IO.Put_Line
        ("  -nesting-threshold=<n>     Set nesting depth limit (default: 4)");
      Ada.Text_IO.Put_Line
        ("  -parameter-threshold=<n>   Set parameter count limit (default: 6)");
      Ada.Text_IO.Put_Line
        ("  -line-length-threshold=<n> Set line length limit (default: 120)");
      Ada.Text_IO.Put_Line ("  -v, -verbose          Enable verbose output");
      Ada.Text_IO.Put_Line ("  -q, -quiet            Suppress summary output");
      Ada.Text_IO.Put_Line ("  --                    Treat items as files");
   end Show_Help;

   --  Prints the tool's version for -version.
   procedure Print_Version is
   begin
      Ada.Text_IO.Put_Line ("adalang-analyzer version 0.1.0-dev");
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

   --  Applies a GCC-style "+R<check>" / "-R<check>" switch, enabling or
   --  disabling exactly the named check.
   procedure Process_Command_Switch (Switch : String) is
      procedure Apply (Name : String; Mode : Rule_State) is
         Found : Boolean;
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
         Found  : Boolean;
         Action : Rule_State := Enabled;
         First  : Positive;
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
            First := Item'First;
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
         Function_Side_Effect, SPARK_Mode);
   begin
      SPARK_Analysis_Mode := True;
      for Rule in Rule_Kind loop
         Rule_States (Rule) := Disabled;
      end loop;

      for Rule of SPARK_Rules loop
         Rule_States (Rule) := Enabled;
      end loop;
   end Enable_SPARK_Preset;

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

   --  Runs the checks that scan Filename's raw source text one line at a
   --  time rather than the parsed AST (Long_Line, Trailing_Whitespace).
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
      then
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
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
      end if;

      Source_File_Count := Source_File_Count + 1;
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
      else
         Checks.Evaluate_Node (Unit, Unit.Root);
      end if;

   exception
      when Exc : others =>
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "Error processing " & Filename & ": " & Ada.Exceptions.Exception_Message (Exc));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Process_File;

   procedure Run is
      Files_To_Process : File_Name_Vectors.Vector;
      Project_Gpr_Files : File_Name_Vectors.Vector;
      Seen_Projects     : File_Name_Vectors.Vector;
      Argument_Count    : constant Natural := Ada.Command_Line.Argument_Count;
      Current_Arg       : Natural := 1;
      Options_Ended     : Boolean := False;
      Ctx               : Libadalang.Analysis.Analysis_Context;
   begin
      --  Left-to-right scan of the command line: switches update the mode
      --  flags/rule states above, everything else (or anything after "--")
      --  is collected as either a project file (-P) or a source file name.
      while Current_Arg <= Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (Current_Arg);
         begin
            if not Options_Ended then
               if Arg = "--" then
                  Options_Ended := True;  --  adalang-analyzer: ignore Dead_Store
               elsif Arg = "-h" or else Arg = "--help" or else Arg = "-help" then
                  Show_Help_Flag := True;
               elsif Arg = "-version" then
                  Show_Version := True;
               elsif Arg = "-list-checks" or else Arg = "-list-rules" then
                  List_Checks_Only := True;
               elsif Arg = "--spark" or else Arg = "-spark" then
                  Enable_SPARK_Preset;
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
                        & Ada.Command_Line.Argument (Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 8 and then Arg (Arg'First .. Arg'First + 7) = "-checks=" then  --  adalang-analyzer: ignore Magic_Number
                  Parse_Checks_Option (Arg);
               elsif Arg = "-complexity-threshold" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: expected positive threshold value");
                     Invalid_Options := True;
                  else
                     Set_Complexity_Threshold
                       (Ada.Command_Line.Argument (Current_Arg + 1));
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
                       (Ada.Command_Line.Argument (Current_Arg + 1));
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
                       (Ada.Command_Line.Argument (Current_Arg + 1));
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
                       (Ada.Command_Line.Argument (Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 23  --  adalang-analyzer: ignore Magic_Number
                 and then Arg (Arg'First .. Arg'First + 22) =  --  adalang-analyzer: ignore Magic_Number
                   "-line-length-threshold="
               then
                  Set_Line_Length_Threshold
                    (Arg (Arg'First + 23 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
               elsif Arg = "-P" then
                  if Current_Arg = Argument_Count then
                     Ada.Text_IO.Put_Line ("adalang-analyzer: expected argument for -P");
                     Invalid_Options := True;
                  else
                     File_Name_Vectors.Append
                       (Project_Gpr_Files,
                        Ada.Command_Line.Argument (Current_Arg + 1));
                     Current_Arg := Current_Arg + 1;
                  end if;
               elsif Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-P" then  --  adalang-analyzer: ignore Magic_Number
                  File_Name_Vectors.Append
                    (Project_Gpr_Files, Arg (Arg'First + 2 .. Arg'Last));  --  adalang-analyzer: ignore Magic_Number
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

      if Show_Help_Flag then
         Show_Help;
         return;
      elsif Show_Version then
         Print_Version;
         return;
      elsif Invalid_Options then
         Show_Help;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      elsif List_Checks_Only then
         Print_Check_List;
         return;
      end if;

      --  Project files contribute their own Ada sources on top of any file
      --  names given directly on the command line.
      for P of Project_Gpr_Files loop
         Load_Project_File (P, Files_To_Process, Seen_Projects);
      end loop;

      if File_Name_Vectors.Is_Empty (Files_To_Process) then
         if Argument_Count > 0 then
            -- Options were provided, but no files
            null;  --  adalang-analyzer: ignore Null_Statement
         else
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                                  "adalang-analyzer: error: no source files provided.");
            Show_Help;
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
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

         Ctx := Libadalang.Analysis.Create_Context
           (Unit_Provider =>
              Adalang_Analyzer.Unit_Provider.Create
                (Primary =>
                   Libadalang.Auto_Provider.Create_Auto_Provider_Reference
                     (Input_Files),
                 Fallback => Libadalang.Unit_Files.Default_Provider));
      end;

      for F of Files_To_Process loop
         Process_File (F, Ctx);
      end loop;

      if not Quiet_Mode then
         Ada.Text_IO.New_Line;
         Ada.Text_IO.Put_Line ("Files scanned : " & To_Decimal (Source_File_Count));
         Ada.Text_IO.Put_Line ("Violations    : " & To_Decimal (Violations));

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

   exception
      when E : others =>
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "Internal error: " & Ada.Exceptions.Exception_Information (E));
         Ada.Command_Line.Set_Exit_Status (2);  --  adalang-analyzer: ignore Magic_Number
   end Run;

end Adalang_Analyzer.CLI;
