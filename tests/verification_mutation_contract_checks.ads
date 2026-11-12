--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

--  What verification_contract_checks proves, where it does not hold. A
--  divisor that can be zero; a 'Length that can exceed the type it is
--  converted to; the bounds of a range constraint outside the subtype they
--  constrain (a bound computed in the base type, the bound of a null
--  array); a returned value outside the result subtype; the arithmetic of
--  a loop invariant whose terms grow. GNATprove proves none of them.

with Interfaces;

package Verification_Mutation_Contract_Checks with SPARK_Mode is
   use type Interfaces.Integer_32, Interfaces.Integer_64;

   subtype I32 is Interfaces.Integer_32;
   subtype Index_16 is I32 range 0 .. 15;
   subtype Index_64 is I32 range 0 .. 63;
   type Byte is mod 2 ** 8;
   type Wide_Array is array (Natural range <>) of Byte;
   type Arr is array (Positive range <>) of Integer;
   type Arr16 is array (Index_16) of I32;
   type Arr64 is array (Index_64) of I32;
   type Small is range 1 .. 10;
   type Small_Arr is array (Small) of Integer;

   type Pair is record
      A, B : Natural := 1;
   end record
     with Dynamic_Predicate => Pair.A mod Pair.B = 0;

   procedure Cases (Bit_Length, Div : Natural; R : out Natural)
     with Contract_Cases => (Bit_Length mod Div = 0 => R = 0,
                             others => R = 1);

   procedure Bits_In (Data : Wide_Array; Bit_Len : Natural; R : out Natural)
     with Pre => Bit_Len <= 1600 and then (Bit_Len + 7) / 8 <= Data'Length;

   function Any_Bound (A : Arr16; I : I32) return Boolean is (True)
     with Pre => (for all K3 in Index_16 range 0 .. I => A (K3) > 0);

   function Next_Bound (A : Small_Arr; J : Small) return Boolean is (True)
     with Pre => (for all K5 in Small range 1 .. J + 1 => A (K5) > 0);

   function Null_First (X : Arr) return Boolean is (True)
     with Pre => (for all K6 in Positive range X'First .. 5 => K6 > 0);

   subtype Bit_Length is Interfaces.Integer_64 range 0 .. 2 ** 34;
   subtype Bit_Index is Interfaces.Integer_64 range 1 .. 2 ** 34;

   type Raw_Context is record
      Start     : Bit_Index := 1;
      Last_Read : Bit_Length := 0;
   end record;

   function Raw_Size (Ctx : Raw_Context) return Bit_Length is
     (Ctx.Last_Read - Ctx.Start + 1);

   function Dec (X : Natural) return Natural is (X - 1);

   function Succ (Y : Small) return Small is (Y + 1);

   procedure Spread (A : in out Arr64; Lim : I32);

   procedure Count_Up (A : out Arr16; N : I32);

   function Is_Ok (Data : Wide_Array; Offset : Natural) return Boolean;

   procedure Grow (Data : Wide_Array; Sum : out Natural);

   subtype N32 is I32 range 0 .. I32'Last;
   type Byte_Seq is array (N32 range <>) of Byte;

   function Other_First (X, Y : Byte_Seq) return Boolean;

end Verification_Mutation_Contract_Checks;
