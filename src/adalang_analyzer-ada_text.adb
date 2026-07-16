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
              and then Text (Index + 1) = '"'
            then
               --  Two quotes encode one quote inside an Ada string literal.
               Append (Result, Text (Index + 1));
               Index := Index + 2;  --  adalang-analyzer: ignore Magic_Number
            else
               In_String := not In_String;
               Index := Index + 1;
            end if;
         elsif In_String then
            Append (Result, Text (Index));
            Index := Index + 1;
         elsif Text (Index) = Character'Val (39)  --  adalang-analyzer: ignore Magic_Number
           and then Index + 2 <= Text'Last  --  adalang-analyzer: ignore Magic_Number
           and then Text (Index + 2) = Character'Val (39)  --  adalang-analyzer: ignore Magic_Number
         then
            --  Preserve the spelling and case of character literals.
            Append (Result, Text (Index .. Index + 2));  --  adalang-analyzer: ignore Magic_Number
            Index := Index + 3;  --  adalang-analyzer: ignore Magic_Number
         elsif Text (Index) not in ' '
           | Ada.Characters.Latin_1.HT
           | Ada.Characters.Latin_1.LF
           | Ada.Characters.Latin_1.CR
         then
            Append (Result, Text_Utils.Lower_Char (Text (Index)));
            Index := Index + 1;
         else
            Index := Index + 1;  --  adalang-analyzer: ignore Dead_Store
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
