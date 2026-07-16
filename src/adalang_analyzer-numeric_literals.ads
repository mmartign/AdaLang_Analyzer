--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

--  Parses Ada numeric literal syntax, including the based form
--  "<base>#<digits>#[e<exponent>]" (e.g. "16#FF#"), which
--  Long_Long_Integer'Value does not accept. Used by Flow_Eval to fold
--  integer literals into Abstract_Int without executing analyzed code.
package Adalang_Analyzer.Numeric_Literals is

   Decimal_Base             : constant Positive := 10;
   Minimum_Ada_Base         : constant Positive := 2;
   Maximum_Ada_Base         : constant Positive := 16;
   Maximum_Integer_Exponent : constant Natural := 63;
   Invalid_Digit_Value      : constant Natural := 36;

   function Strip_Underscores (Text : String) return String;
   --  Removes numeric-literal digit-group underscores (e.g. "1_000") and
   --  lower-cases the rest, producing a form Long_Long_Integer'Value /
   --  Long_Long_Float'Value or Parse_Integer_Text can consume.

   function Digit_Value (Char : Character) return Natural;
   --  Value of a base-16 digit (0-9, a-f); Invalid_Digit_Value (an
   --  impossible digit in any Ada numeric base, which range up to 16)
   --  signals "not a digit".

   function Parse_Unsigned
     (Text : String; Base : Positive; Value : out Long_Long_Integer)
      return Boolean;
   --  Parses Text as an unsigned integer in the given Base, rejecting
   --  out-of-range digits and overflow rather than raising.

   function Parse_Exponent
     (Text : String; Value : out Natural) return Boolean;
   --  Parses the "e<digits>" suffix of an Ada numeric literal (Text is the
   --  part after 'e'); a missing suffix is a valid exponent of 0.

   function Multiply_By_Power
     (Value : Long_Long_Integer; Base : Positive; Exponent : Natural;
      Result : out Long_Long_Integer) return Boolean;
   --  Computes Value * Base**Exponent, returning False on overflow instead
   --  of raising Constraint_Error.

   function Parse_Integer_Text
     (Raw_Text : String; Value : out Long_Long_Integer) return Boolean;
   --  Parses an Ada integer literal, including the based form and the
   --  decimal form with an optional exponent (e.g. "12e3").

end Adalang_Analyzer.Numeric_Literals;
