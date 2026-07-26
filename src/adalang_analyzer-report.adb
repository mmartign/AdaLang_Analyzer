--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Latin_1;
with Ada.Containers;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces;

with Adalang_Analyzer.Config;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Report is

   use Ada.Strings.Unbounded;

   type Finding is record
      Filename       : Unbounded_String;
      Line_Number    : Natural;
      Column         : Natural;
      Caret_Width    : Natural;
      Rule           : Rules.Rule_Kind;
      Message        : Unbounded_String;
      Source_Text    : Unbounded_String;
      Fingerprint    : Unbounded_String;
      Matches_Base   : Boolean := False;
   end record;

   package Finding_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Finding);

   --  A count per fingerprint, not a plain set: two distinct findings can
   --  legitimately share one fingerprint (it deliberately excludes line and
   --  column so line churn doesn't manufacture a new finding), e.g. two
   --  identical "null;" placeholders in the same file. Tracking how many
   --  occurrences were actually baselined, and consuming one per match,
   --  keeps a genuinely new occurrence of an already-baselined shape from
   --  being silently treated as pre-existing.
   package Fingerprint_Count_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Natural,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Findings          : Finding_Vectors.Vector;
   Baseline          : Fingerprint_Count_Maps.Map;
   Current_Format    : Output_Format := Text_Output;
   Output_Filename   : Unbounded_String;

   function Selected_Output_Format return Output_Format is (Current_Format);

   procedure Set_Output
     (Format   : Output_Format;
      Filename : String := "") is
   begin
      Current_Format  := Format;
      Output_Filename := To_Unbounded_String (Filename);
   end Set_Output;

   function Normalized_Path (Filename : String) return String is
      First   : Integer := Filename'First;
      Value   : String := Filename;
      Current : String := Ada.Directories.Current_Directory;
   begin
      for C of Value loop
         if C = '\' then
            C := '/';
         end if;
      end loop;
      for C of Current loop
         if C = '\' then
            C := '/';
         end if;
      end loop;

      if Value'Length > Current'Length
        and then Value
          (Value'First .. Value'First + Current'Length - 1) = Current
        and then Value (Value'First + Current'Length) = '/'
      then
         First := Value'First + Current'Length + 1;
      end if;

      while First + 1 <= Value'Last
        and then Value (First .. First + 1) = "./"
      loop
         First := First + 2;
      end loop;

      if First > Value'Last then
         return "";
      else
         return Value (First .. Value'Last);
      end if;
   end Normalized_Path;

   function Hex_Digit (Value : Interfaces.Unsigned_64) return Character is
      Hex_Chars : constant String := "0123456789abcdef";
   begin
      return Hex_Chars (Natural (Value) + 1);
   end Hex_Digit;

   function Stable_Fingerprint
     (Filename    : String;
      Rule_Name   : String;
      Message     : String;
      Source_Text : String) return String
   is
      use type Interfaces.Unsigned_64;

      Hash  : Interfaces.Unsigned_64 := 16#CBF29CE484222325#;
      Prime : constant Interfaces.Unsigned_64 := 16#100000001B3#;
      Key   : constant String :=
        Normalized_Path (Filename) & Character'Val (0) &
        Rule_Name & Character'Val (0) & Message & Character'Val (0) &
        Ada.Strings.Fixed.Trim (Source_Text, Ada.Strings.Both);
      Result : String (1 .. 16);
      Value  : Interfaces.Unsigned_64;
   begin
      for C of Key loop
         Hash := (Hash xor Interfaces.Unsigned_64 (Character'Pos (C))) * Prime;
      end loop;

      Value := Hash;
      for Index in reverse Result'Range loop
         Result (Index) := Hex_Digit (Value and 16#F#);
         Value := Interfaces.Shift_Right (Value, 4);
      end loop;
      return Result;
   end Stable_Fingerprint;

   function JSON_Escape (Value : String) return String is
      Result : Unbounded_String;
      Hex    : constant String := "0123456789abcdef";
   begin
      for C of Value loop
         case C is
            when '"' =>
               Append (Result, '\');
               Append (Result, '"');
            when '\' =>
               Append (Result, '\');
               Append (Result, '\');
            when Ada.Characters.Latin_1.LF =>
               Append (Result, "\n");
            when Ada.Characters.Latin_1.CR =>
               Append (Result, "\r");
            when Ada.Characters.Latin_1.HT =>
               Append (Result, "\t");
            when others =>
               if Character'Pos (C) < 32 then
                  Append (Result, "\u00");
                  Append
                    (Result,
                     Hex (Character'Pos (C) / 16 + 1));
                  Append
                    (Result,
                     Hex (Character'Pos (C) mod 16 + 1));
               else
                  Append (Result, C);
               end if;
         end case;
      end loop;
      return To_String (Result);
   end JSON_Escape;

   --  Percent-encodes Value so it is a syntactically valid URI reference,
   --  as SARIF's artifactLocation.uri requires. A space, '#', '?', '%', or
   --  any other byte outside the unreserved set (and '/', kept literal so
   --  the path structure survives) would otherwise produce a URI a strict
   --  SARIF consumer can reject outright.
   function URI_Escape (Value : String) return String is
      Result : Unbounded_String;
      Hex    : constant String := "0123456789ABCDEF";
   begin
      for C of Value loop
         case C is
            when 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9'
               | '-' | '.' | '_' | '~' | '/' =>
               Append (Result, C);
            when others =>
               Append (Result, '%');
               Append (Result, Hex (Character'Pos (C) / 16 + 1));
               Append (Result, Hex (Character'Pos (C) mod 16 + 1));
         end case;
      end loop;
      return To_String (Result);
   end URI_Escape;

   --  Records one more baselined occurrence of Fingerprint.
   procedure Add_Baseline_Occurrence (Fingerprint : String) is
      Cursor : constant Fingerprint_Count_Maps.Cursor :=
        Fingerprint_Count_Maps.Find (Baseline, Fingerprint);
   begin
      if Fingerprint_Count_Maps.Has_Element (Cursor) then
         Fingerprint_Count_Maps.Replace_Element
           (Baseline, Cursor,
            Fingerprint_Count_Maps.Element (Cursor) + 1);
      else
         Fingerprint_Count_Maps.Insert (Baseline, Fingerprint, 1);
      end if;
   end Add_Baseline_Occurrence;

   --  Claims one baselined occurrence of Fingerprint if any remain, so a
   --  shape baselined N times excuses only its first N occurrences in this
   --  run; any further occurrence of the same shape is reported as new.
   function Consume_Baseline_Occurrence (Fingerprint : String) return Boolean
   is
      Cursor : constant Fingerprint_Count_Maps.Cursor :=
        Fingerprint_Count_Maps.Find (Baseline, Fingerprint);
   begin
      if not Fingerprint_Count_Maps.Has_Element (Cursor) then
         return False;
      end if;

      declare
         Remaining : constant Natural := Fingerprint_Count_Maps.Element (Cursor);
      begin
         if Remaining = 0 then
            return False;
         elsif Remaining = 1 then
            Fingerprint_Count_Maps.Delete (Baseline, Fingerprint);
         else
            Fingerprint_Count_Maps.Replace_Element
              (Baseline, Cursor, Remaining - 1);
         end if;
         return True;
      end;
   end Consume_Baseline_Occurrence;

   procedure Load_Baseline (Filename : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String :=
              Ada.Strings.Fixed.Trim
                (Ada.Text_IO.Get_Line (File), Ada.Strings.Both);
         begin
            if Line /= "" and then Line (Line'First) /= '#' then
               Add_Baseline_Occurrence (Line);
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Load_Baseline;

   procedure Write_Baseline (Filename : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Filename);
      Ada.Text_IO.Put_Line
        (File, "# AdaLang Analyzer finding fingerprints, version 2");
      --  One line per finding, not deduplicated: a fingerprint that
      --  legitimately occurs N times in this run must be written N times,
      --  so Load_Baseline restores the same per-shape occurrence count
      --  rather than only ever excusing a single occurrence.
      for Item of Findings loop
         Ada.Text_IO.Put_Line (File, To_String (Item.Fingerprint));
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Write_Baseline;

   function SARIF_Level (Severity : Rules.Issue_Severity) return String is
   begin
      case Severity is
         when Rules.Severity_Blocker | Rules.Severity_High =>
            return "error";
         when Rules.Severity_Medium =>
            return "warning";
         when Rules.Severity_Low =>
            return "note";
      end case;
   end SARIF_Level;

   procedure Emit_JSON (File : Ada.Text_IO.File_Type) is
      First : Boolean := True;
   begin
      Ada.Text_IO.Put_Line (File, "{");
      Ada.Text_IO.Put_Line
        (File, "  ""version"": ""1.0"",");
      Ada.Text_IO.Put_Line
        (File, "  ""assuranceProfile"": """ &
         JSON_Escape (Config.Assurance_Profile_Name) & """,");
      Ada.Text_IO.Put_Line
        (File, "  ""structuralCoverageObjective"": """ &
         JSON_Escape (Config.Structural_Coverage_Objective) & """,");
      Ada.Text_IO.Put_Line
        (File, "  ""certificationClaim"": " &
         """verification support only; not a compliance determination"",");
      Ada.Text_IO.Put_Line
        (File, "  ""filesScanned"": " &
         Text_Utils.To_Decimal (Source_File_Count) & ",");
      Ada.Text_IO.Put_Line
        (File, "  ""newViolations"": " &
         Text_Utils.To_Decimal (Violations) & ",");
      Ada.Text_IO.Put_Line
        (File, "  ""baselineMatches"": " &
         Text_Utils.To_Decimal (Baseline_Matches) & ",");
      Ada.Text_IO.Put_Line (File, "  ""findings"": [");
      for Item of Findings loop
         if not First then
            Ada.Text_IO.Put_Line (File, ",");
         end if;
         First := False;
         declare
            Info : Rules.Rule_Info renames Rules.Rule_Infos (Item.Rule);
         begin
            Ada.Text_IO.Put
              (File,
               "    {""ruleId"": """ &
               JSON_Escape (To_String (Info.Name)) &
               """, ""message"": """ &
               JSON_Escape (To_String (Item.Message)) &
               """, ""file"": """ &
               JSON_Escape (Normalized_Path (To_String (Item.Filename))) &
               """, ""line"": " &
               Text_Utils.To_Decimal (Item.Line_Number) &
               ", ""column"": " & Text_Utils.To_Decimal (Item.Column) &
               ", ""severity"": """ &
               JSON_Escape (Rules.Severity_Name (Info.Severity)) &
               """, ""quality"": """ &
               JSON_Escape (Rules.Quality_Name (Info.Quality)) &
               """, ""fingerprint"": """ &
               To_String (Item.Fingerprint) &
               """, ""baseline"": " &
               (if Item.Matches_Base then "true" else "false") & "}");
         end;
      end loop;
      Ada.Text_IO.New_Line (File);
      Ada.Text_IO.Put_Line (File, "  ]");
      Ada.Text_IO.Put_Line (File, "}");
   end Emit_JSON;

   procedure Emit_SARIF (File : Ada.Text_IO.File_Type) is
      First : Boolean := True;
   begin
      Ada.Text_IO.Put_Line
        (File, "{""version"": ""2.1.0"", ""$schema"": " &
         """https://json.schemastore.org/sarif-2.1.0.json"", ""runs"": [{");
      Ada.Text_IO.Put_Line
        (File, "  ""tool"": {""driver"": {""name"": ""AdaLang Analyzer"", " &
         """version"": ""0.1.0-dev"", ""informationUri"": " &
         """https://spazioit.com/"", ""rules"": [");
      for Rule in Rules.Rule_Kind loop
         if not First then
            Ada.Text_IO.Put_Line (File, ",");
         end if;
         First := False;
         Ada.Text_IO.Put
           (File,
            "    {""id"": """ &
            JSON_Escape (To_String (Rules.Rule_Infos (Rule).Name)) &
            """, ""shortDescription"": {""text"": """ &
            JSON_Escape (To_String (Rules.Rule_Infos (Rule).Description)) &
            """}, ""help"": {""text"": """ &
            JSON_Escape (To_String (Rules.Rule_Infos (Rule).Guidance)) &
            """}}");
      end loop;
      Ada.Text_IO.New_Line (File);
      Ada.Text_IO.Put_Line (File, "  ]}},");
      Ada.Text_IO.Put_Line
        (File, "  ""properties"": {""assuranceProfile"": """ &
         JSON_Escape (Config.Assurance_Profile_Name) &
         """, ""structuralCoverageObjective"": """ &
         JSON_Escape (Config.Structural_Coverage_Objective) &
         """, ""certificationClaim"": " &
         """verification support only; not a compliance determination""},");
      Ada.Text_IO.Put_Line (File, "  ""results"": [");
      First := True;
      for Item of Findings loop
         if not First then
            Ada.Text_IO.Put_Line (File, ",");
         end if;
         First := False;
         declare
            Info : Rules.Rule_Info renames Rules.Rule_Infos (Item.Rule);
         begin
            Ada.Text_IO.Put
              (File,
               "    {""ruleId"": """ &
               JSON_Escape (To_String (Info.Name)) &
               """, ""level"": """ & SARIF_Level (Info.Severity) &
               """, ""message"": {""text"": """ &
               JSON_Escape (To_String (Item.Message)) &
               """}, ""baselineState"": """ &
               (if Item.Matches_Base then "unchanged" else "new") &
               """, ""partialFingerprints"": {""adalang/v1"": """ &
               To_String (Item.Fingerprint) &
               """}, ""locations"": [{""physicalLocation"": {" &
               """artifactLocation"": {""uri"": """ &
               JSON_Escape
                 (URI_Escape (Normalized_Path (To_String (Item.Filename)))) &
               """}, ""region"": {""startLine"": " &
               Text_Utils.To_Decimal (Item.Line_Number) &
               ", ""startColumn"": " &
               Text_Utils.To_Decimal (Item.Column) &
               "}}}]}");
         end;
      end loop;
      Ada.Text_IO.New_Line (File);
      Ada.Text_IO.Put_Line (File, "  ]");
      Ada.Text_IO.Put_Line (File, "}]}");
   end Emit_SARIF;

   procedure Finalize_Output is
      File : Ada.Text_IO.File_Type;
      Name : constant String := To_String (Output_Filename);
   begin
      if Current_Format = Text_Output then
         return;
      end if;

      if Name = "" then
         if Current_Format = JSON_Output then
            Emit_JSON (Ada.Text_IO.Standard_Output);
         else
            Emit_SARIF (Ada.Text_IO.Standard_Output);
         end if;
      else
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
         if Current_Format = JSON_Output then
            Emit_JSON (File);
         else
            Emit_SARIF (File);
         end if;
         Ada.Text_IO.Close (File);
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Finalize_Output;

   function Source_Line
     (Filename : String; Line_Number : Natural) return String
   is
      File         : Ada.Text_IO.File_Type;
      Current_Line : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Current_Line := Current_Line + 1;

            if Current_Line = Line_Number then
               Ada.Text_IO.Close (File);
               return Line;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return "";

   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return "";
   end Source_Line;

   function Is_Suppressed
     (Source_Text : String; Rule_Name : String) return Boolean
   is
      Marker : constant String :=
        "adalang-analyzer: ignore " & Rule_Name;
   begin
      return Ada.Strings.Fixed.Index (Source_Text, Marker) /= 0;
   end Is_Suppressed;

   function Is_Generated_Config_File (Filename : String) return Boolean is
      Suffix : constant String := "_config.ads";
   begin
      return Filename'Length >= Suffix'Length
        and then Filename
          (Filename'Last - Suffix'Length + 1 .. Filename'Last) = Suffix;
   end Is_Generated_Config_File;

   function Highlight_Width
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Start_Line   : constant Natural := Natural (Node.Sloc_Range.Start_Line);
      End_Line     : constant Natural := Natural (Node.Sloc_Range.End_Line);
      Start_Column : constant Natural := Natural (Node.Sloc_Range.Start_Column);
      End_Column   : constant Natural := Natural (Node.Sloc_Range.End_Column);
      Width        : Natural := 1;
   begin
      if Start_Line = End_Line and then End_Column > Start_Column then
         Width := End_Column - Start_Column;
      end if;

      if Width > Maximum_Highlight_Width then
         return Maximum_Highlight_Width;
      else
         return Width;
      end if;
   end Highlight_Width;

   procedure Report_Violation_At
     (Filename    : String;
      Line_Number : Natural;
      Column      : Natural;
      Caret_Width : Natural;
      Rule        : Rules.Rule_Kind;
      Message     : String)
   is
      Rule_Name    : constant String :=
        Ada.Strings.Unbounded.To_String (Rules.Rule_Infos (Rule).Name);
      Source_Text  : constant String := Source_Line (Filename, Line_Number);
      Fingerprint  : constant String :=
        Stable_Fingerprint (Filename, Rule_Name, Message, Source_Text);
      Matches_Base : constant Boolean :=
        Consume_Baseline_Occurrence (Fingerprint);
   begin
      if Is_Suppressed (Source_Text, Rule_Name) then
         return;
      end if;

      Finding_Vectors.Append
        (Findings,
         (Filename     => To_Unbounded_String (Filename),
          Line_Number  => Line_Number,
          Column       => Column,
          Caret_Width  => Caret_Width,
          Rule         => Rule,
          Message      => To_Unbounded_String (Message),
          Source_Text  => To_Unbounded_String (Source_Text),
          Fingerprint  => To_Unbounded_String (Fingerprint),
          Matches_Base => Matches_Base));

      if Matches_Base then
         Baseline_Matches := Baseline_Matches + 1;
      else
         Violations := Violations + 1;
         Rule_Violations (Rule) := Rule_Violations (Rule) + 1;
      end if;

      if not Matches_Base
        and then Current_Format = Text_Output
        and then not Config.Quiet_Mode
      then
         Ada.Text_IO.Put_Line (Filename & ":" &
                   Text_Utils.To_Decimal (Line_Number) & ":" &
                   Text_Utils.To_Decimal (Column) &
                   ": warning: " & Message & " [" &
                   Rule_Name & "]");
         Ada.Text_IO.Put_Line ("  rule: " &
                   Ada.Strings.Unbounded.To_String
                     (Rules.Rule_Infos (Rule).Description));
         Ada.Text_IO.Put_Line ("  advice: " &
                   Ada.Strings.Unbounded.To_String
                     (Rules.Rule_Infos (Rule).Guidance));
         Ada.Text_IO.Put_Line ("  quality: " &
                   Rules.Quality_Name (Rules.Rule_Infos (Rule).Quality) &
                   " (" &
                   Rules.Severity_Name (Rules.Rule_Infos (Rule).Severity) &
                   ")");

         if Source_Text /= "" then
            Ada.Text_IO.Put_Line ("  source:");
            Ada.Text_IO.Put_Line ("    " & Source_Text);

            if Column > 0 then
               Ada.Text_IO.Put_Line
                 ("    " & Text_Utils.Repeat_Char (' ', Column - 1) &
                  Text_Utils.Repeat_Char ('^', Caret_Width));
            end if;
         end if;
      end if;
   end Report_Violation_At;

   procedure Report_Rule_Violation
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Rule    : Rules.Rule_Kind;
      Message : String) is
   begin
      Report_Violation_At
        (Filename    => Unit.Get_Filename,
         Line_Number => Natural (Node.Sloc_Range.Start_Line),
         Column      => Natural (Node.Sloc_Range.Start_Column),
         Caret_Width => Highlight_Width (Node),
         Rule        => Rule,
         Message     => Message);
   end Report_Rule_Violation;

   procedure Report_Line_Violation
     (Filename    : String;
      Line_Number : Natural;
      Column      : Natural;
      Caret_Width : Natural;
      Rule        : Rules.Rule_Kind;
      Message     : String) is
   begin
      Report_Violation_At
        (Filename    => Filename,
         Line_Number => Line_Number,
         Column      => Column,
         Caret_Width => Caret_Width,
         Rule        => Rule,
         Message     => Message);
   end Report_Line_Violation;

end Adalang_Analyzer.Report;
