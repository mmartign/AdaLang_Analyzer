--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Adalang_Analyzer.Config;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Report is

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
   begin
      if Is_Suppressed (Source_Text, Rule_Name) then
         return;
      end if;

      Violations := Violations + 1;
      Rule_Violations (Rule) := Rule_Violations (Rule) + 1;

      if not Config.Quiet_Mode then
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
