--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Numeric_Literals is

   function Strip_Underscores (Text : String) return String is
      Result : Unbounded_String;
   begin
      for Char of Text loop
         if Char /= '_' then
            Append (Result, Text_Utils.Lower_Char (Char));
         end if;
      end loop;

      return To_String (Result);
   end Strip_Underscores;

   function Digit_Value (Char : Character) return Natural is
   begin
      if Char in '0' .. '9' then
         return Character'Pos (Char) - Character'Pos ('0');
      elsif Char in 'a' .. 'f' then
         return Decimal_Base + Character'Pos (Char) - Character'Pos ('a');
      else
         return Invalid_Digit_Value;
      end if;
   end Digit_Value;

   function Parse_Unsigned
     (Text : String; Base : Positive; Value : out Long_Long_Integer)
      return Boolean
   is
      Result : Long_Long_Integer := 0;
   begin
      if Text = "" then
         return False;
      end if;

      for Char of Text loop
         declare
            Digit : constant Natural := Digit_Value (Char);
         begin
            if Digit >= Base then
               return False;
            end if;

            if Result >
              (Long_Long_Integer'Last - Long_Long_Integer (Digit)) /
              Long_Long_Integer (Base)
            then
               return False;
            end if;

            Result := Result * Long_Long_Integer (Base) +
              Long_Long_Integer (Digit);
         end;
      end loop;

      Value := Result;
      return True;
   end Parse_Unsigned;

   function Parse_Exponent
     (Text : String; Value : out Natural) return Boolean
   is
      Start  : Positive := Text'First;
      Parsed : Long_Long_Integer;
   begin
      if Text = "" then
         Value := 0;
         return True;
      end if;

      if Text (Start) = '+' then
         Start := Start + 1;
      elsif Text (Start) = '-' then
         return False;
      end if;

      if Start > Text'Last then
         return False;
      end if;

      if not Parse_Unsigned (Text (Start .. Text'Last), Decimal_Base, Parsed) then
         return False;
      elsif Parsed > Long_Long_Integer (Natural'Last) then
         return False;  --  adalang-analyzer: ignore Identical_Branches
      else
         Value := Natural (Parsed);
         return True;
      end if;
   end Parse_Exponent;

   function Multiply_By_Power
     (Value : Long_Long_Integer; Base : Positive; Exponent : Natural;
      Result : out Long_Long_Integer) return Boolean
   is
      Current : Long_Long_Integer := Value;
   begin
      if Exponent > Maximum_Integer_Exponent then
         return False;
      end if;

      for Count in 1 .. Exponent loop
         if Current >
           Long_Long_Integer'Last / Long_Long_Integer (Base)
         then
            return False;
         end if;

         Current := Current * Long_Long_Integer (Base);
      end loop;

      Result := Current;
      return True;
   end Multiply_By_Power;

   function Parse_Integer_Text  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Raw_Text : String; Value : out Long_Long_Integer) return Boolean
   is
      Text       : constant String := Strip_Underscores (Raw_Text);
      Hash_1     : Natural;
      Hash_2     : Natural;
      Exp_Index  : Natural;
      Base_Value : Long_Long_Integer;
      Number     : Long_Long_Integer;
      Exponent   : Natural := 0;
   begin
      if Text = "" then
         return False;
      end if;

      Hash_1 := Text_Utils.Find_Char (Text, '#', Text'First);

      if Hash_1 /= 0 then
         if Hash_1 = Text'First then
            return False;
         end if;

         Hash_2 := Text_Utils.Find_Char (Text, '#', Hash_1 + 1);

         if Hash_2 = 0 or else Hash_2 = Hash_1 + 1 then
            return False;
         end if;

         if not Parse_Unsigned
           (Text (Text'First .. Hash_1 - 1), Decimal_Base, Base_Value)
           or else Base_Value < Long_Long_Integer (Minimum_Ada_Base)
           or else Base_Value > Long_Long_Integer (Maximum_Ada_Base)
         then
            return False;
         end if;

         if not Parse_Unsigned
           (Text (Hash_1 + 1 .. Hash_2 - 1), Positive (Base_Value), Number)
         then
            return False;
         end if;

         if Hash_2 < Text'Last then
            if Text (Hash_2 + 1) /= 'e' then
               return False;
            end if;

            if not Parse_Exponent
              (Text (Hash_2 + 2 .. Text'Last), Exponent)  --  adalang-analyzer: ignore Magic_Number
            then
               return False;
            end if;
         end if;

         return Multiply_By_Power
           (Number, Positive (Base_Value), Exponent, Value);
      end if;

      Exp_Index := Text_Utils.Find_Char (Text, 'e', Text'First);

      if Exp_Index = 0 then
         return Parse_Unsigned (Text, Decimal_Base, Value);
      elsif Exp_Index = Text'First then
         return False;
      else
         if not Parse_Unsigned
           (Text (Text'First .. Exp_Index - 1), Decimal_Base, Number)
         then
            return False;
         end if;

         if not Parse_Exponent
           (Text (Exp_Index + 1 .. Text'Last), Exponent)
         then
            return False;
         end if;

         return Multiply_By_Power (Number, Decimal_Base, Exponent, Value);
      end if;
   end Parse_Integer_Text;

end Adalang_Analyzer.Numeric_Literals;
