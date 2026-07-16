--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;

package body Adalang_Analyzer.Text_Utils is

   function To_Decimal (N : Natural) return String is
      Result : String := Natural'Image (N);
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

end Adalang_Analyzer.Text_Utils;
