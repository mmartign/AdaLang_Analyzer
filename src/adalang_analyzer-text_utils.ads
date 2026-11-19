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

   function Without_CR (Line : String) return String;
   --  Line without the carriage return that ends it, if any. Ada.Text_IO
   --  removes it from a line of a file written on Windows when it reads
   --  the file on Windows, not elsewhere: a source, a baseline or a
   --  configuration file then reads the same on every host.

   function Report_Path (Filename : String) return String;
   --  Filename as the reports show it: relative to the current directory
   --  when it is in it, with '/' separators. Libadalang gives an absolute
   --  name, which would make what is reported depend on where the sources
   --  are. On Windows, where file names do not depend on case, neither
   --  does the match with the current directory: "c:\x" is in "C:\".

end Adalang_Analyzer.Text_Utils;
