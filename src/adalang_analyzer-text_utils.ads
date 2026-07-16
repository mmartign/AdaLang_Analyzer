--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

--  Small string helpers with no dependency on Libadalang or on any other
--  AdaLang Analyzer package. Kept separate so the rule registry, the CLI,
--  and the semantic-analysis packages can all share them without pulling
--  in each other.
package Adalang_Analyzer.Text_Utils is

   function To_Decimal (N : Natural) return String;
   --  Natural'Image without the leading space it adds for non-negative
   --  values, for compact "line:column:" style output.

   function Repeat_Char (Char : Character; Count : Natural) return String;
   --  Count copies of Char, used to draw the "^^^" underline beneath a
   --  reported source excerpt.

   function Lower_Char (Char : Character) return Character;
   --  ASCII-only lower-casing; avoids pulling in Ada.Characters.Handling
   --  for the single case this tool needs (Ada source is ASCII-identified).

   function Normalize_Rule_Name (Name : String) return String;
   --  Folds a check name to a case- and separator-insensitive form so
   --  "No_Goto", "no-goto", and "NO_GOTO" all match the same check.

   function Find_Char
     (Text : String; Char : Character; From : Positive) return Natural;
   --  Index of the first occurrence of Char at or after From, or 0 if
   --  there is none (mirrors Ada.Strings.Fixed.Index's "not found" case
   --  without needing that package's Mapping/Pattern machinery).

   function Has_Suffix (Text : String; Suffix : String) return Boolean;
   --  True when Text ends with Suffix.

end Adalang_Analyzer.Text_Utils;
