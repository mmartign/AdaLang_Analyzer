--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Latin_1;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Libadalang.Common;
with Langkit_Support.Text;

with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Ada_Text is

   Next_Character_Offset       : constant Positive := 1;
   Escaped_Quote_Length        : constant Positive := 2;
   Closing_Apostrophe_Offset   : constant Positive := 2;
   Character_Literal_Length    : constant Positive := 3;
   Apostrophe                  : constant Character := Character'Val (39);

   function Node_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return "";
      else
         return Langkit_Support.Text.To_UTF8
           (Libadalang.Analysis.Text (Node));
      end if;
   end Node_Text;

   function Canonical_Text  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Node : Libadalang.Analysis.Ada_Node'Class) return String
   is
      Text      : constant String := Node_Text (Node);
      Result    : Unbounded_String;
      Index     : Natural := Text'First;
      In_String : Boolean := False;
   begin
      while Index <= Text'Last loop
         if Text (Index) = '"' then
            Append (Result, Text (Index));
            if In_String and then Index < Text'Last
              and then Text (Index + Next_Character_Offset) = '"'
            then
               --  Two quotes encode one quote inside an Ada string literal.
               Append (Result, Text (Index + Next_Character_Offset));
               Index := Index + Escaped_Quote_Length;
            else
               In_String := not In_String;
               Index := Index + Next_Character_Offset;
            end if;
         elsif In_String then
            Append (Result, Text (Index));
            Index := Index + Next_Character_Offset;
         elsif Text (Index) = Apostrophe
           and then Index + Closing_Apostrophe_Offset <= Text'Last
           and then Text (Index + Closing_Apostrophe_Offset) = Apostrophe
         then
            --  Preserve the spelling and case of character literals.
            Append
              (Result, Text (Index .. Index + Closing_Apostrophe_Offset));
            Index := Index + Character_Literal_Length;
         elsif Text (Index) not in ' '
           | Ada.Characters.Latin_1.HT
           | Ada.Characters.Latin_1.LF
           | Ada.Characters.Latin_1.CR
         then
            Append (Result, Text_Utils.Lower_Char (Text (Index)));
            Index := Index + Next_Character_Offset;
         else
            Index := Index + Next_Character_Offset;
         end if;
      end loop;

      return To_String (Result);
   end Canonical_Text;

   function Terminates_Statement
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt
            | Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            return True;

         when Libadalang.Common.Ada_Exit_Stmt =>
            return Libadalang.Analysis.Is_Null
              (Node.As_Exit_Stmt.F_Cond_Expr);

         when others =>
            return False;
      end case;
   end Terminates_Statement;

end Adalang_Analyzer.Ada_Text;
