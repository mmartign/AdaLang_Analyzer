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

with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;

with GNAT.OS_Lib;

package body Adalang_Analyzer.Text_Utils is

   function To_Decimal (N : Natural) return String is
      Result : constant String := Natural'Image (N);
   begin
      return Ada.Strings.Fixed.Trim (Result, Ada.Strings.Both);
   end To_Decimal;

   function Repeat_Char (Char : Character; Count : Natural) return String is
   begin
      if Count = 0 then
         return "";
      end if;

      declare
         Result : constant String (1 .. Count) := (others => Char);
      begin
         return Result;
      end;
   end Repeat_Char;

   function Lower_Char (Char : Character) return Character is
   begin
      if Char in 'A' .. 'Z' then
         return Ada.Characters.Handling.To_Lower (Char);
      else
         return Char;
      end if;
   end Lower_Char;

   function Normalize_Rule_Name (Name : String) return String is
      Result : String (Name'Range) := Name;
   begin
      for I in Result'Range loop
         if Result (I) in 'A' .. 'Z' then
            Result (I) := Ada.Characters.Handling.To_Lower (Result (I));
         elsif Result (I) = '_' then
            Result (I) := '-';
         end if;
      end loop;
      return Result;
   end Normalize_Rule_Name;

   function Find_Char
     (Text : String; Char : Character; From : Positive) return Natural
   is
   begin
      if Text = "" or else From > Text'Last then
         return 0;
      end if;

      for Index in From .. Text'Last loop
         if Text (Index) = Char then
            return Index;
         end if;
      end loop;

      return 0;
   end Find_Char;

   function Has_Suffix (Text : String; Suffix : String) return Boolean is
   begin
      return Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
   end Has_Suffix;

   function Without_CR (Line : String) return String is
     (if Line'Length > 0 and then Line (Line'Last) = ASCII.CR
      then Line (Line'First .. Line'Last - 1)
      else Line);

   --  Path with every backslash a slash.
   function Forward (Path : String) return String is
      Result : String := Path;
   begin
      for C of Result loop
         if C = '\' then
            C := '/';
         end if;
      end loop;
      return Result;
   end Forward;

   --  The directory the analyzer runs in, which it never leaves: asked of
   --  the system once, not for every path reported, which on a large
   --  verification run was a seventh of the time.
   Current : constant String := Forward (Ada.Directories.Current_Directory);

   function Report_Path (Filename : String) return String is
      Ignore_Case : constant Boolean := GNAT.OS_Lib.Directory_Separator = '\';

      function Folded (Path : String) return String is
        (if Ignore_Case then Ada.Characters.Handling.To_Lower (Path)
         else Path);

      Value   : constant String := Forward (Filename);
      First   : Integer := Value'First;
   begin
      if Value'Length > Current'Length
        and then Folded (Value (Value'First .. Value'First + Current'Length - 1))
                 = Folded (Current)
        and then Value (Value'First + Current'Length) = '/'
      then
         First := Value'First + Current'Length + 1;
      end if;

      while First + 1 <= Value'Last
        and then Value (First .. First + 1) = "./"
      loop
         First := First + 2;
      end loop;

      return
        (if First > Value'Last then ""
         else Value (First .. Value'Last));
   end Report_Path;

end Adalang_Analyzer.Text_Utils;
