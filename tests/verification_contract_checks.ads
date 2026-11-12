--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

--  Runtime checks where GNATprove raises them and proves them: a division
--  by a static value in a predicate, a default initial condition and a
--  contract case; a 'Length an operand of a typed expression converts;
--  the bounds of a range constraint of a quantified expression and of a
--  for loop; the value a function returns; the arithmetic of a loop
--  invariant, in each state it is evaluated in, where another invariant
--  of the loop is not proved. verification_mutation_contract_checks has
--  what does not hold.

with Interfaces;

package Verification_Contract_Checks with SPARK_Mode is
   use type Interfaces.Integer_32, Interfaces.Integer_64;

   subtype I32 is Interfaces.Integer_32;
   subtype I64 is Interfaces.Integer_64;
   subtype Index_16 is I32 range 0 .. 15;
   subtype Index_64 is I32 range 0 .. 63;
   type Byte is mod 2 ** 8;
   subtype Index_Number is Natural range 0 .. Natural'Last - 1;
   type Byte_Array is array (Index_Number range <>) of Byte;
   type Arr16 is array (Index_16) of I32;
   type Arr64 is array (Index_64) of I32;

   subtype Rate_Bits is Positive range 8 .. 1600
     with Dynamic_Predicate => Rate_Bits mod 8 = 0;

   type Ctx_D is private
     with Default_Initial_Condition => First_Of (Ctx_D) rem Byte'Size = 0;
   function First_Of (X : Ctx_D) return Natural;

   procedure Cases (Bit_Length : Natural; R : out Natural)
     with Contract_Cases => (Bit_Length mod 16 = 0 => R = 0,
                             others => R = 1);

   procedure Bits_In (Data : Byte_Array; Bit_Len : Natural; R : out Natural)
     with Pre => Bit_Len <= 1600 and then (Bit_Len + 7) / 8 <= Data'Length;

   function Ones (A : Arr16; I : I32) return Boolean is (True)
     with Pre => I in 0 .. 15
                 and then (for all K1 in Index_16 range 1 .. I => A (K1) > 0);

   function Tail (A : Arr16; I : I32) return Boolean is (True)
     with Pre => I <= 15
                 and then (for all K2 in Index_16 range 3 .. I => A (K2) > 0);

   function Sum_Bound (A : Arr16; I, J : I32) return Boolean is (True)
     with Pre => I in 0 .. 15 and then J in 0 .. 15 and then I + J <= 15
                 and then (for all K9 in Index_16 range 0 .. I + J =>
                             A (K9) > 0);

   subtype Bit_Length is I64 range 0 .. 2 ** 34;
   subtype Bit_Index is I64 range 1 .. 2 ** 34;

   type Context is record
      First         : Bit_Index := 1;
      Last          : Bit_Length := 0;
      Verified_Last : Bit_Length := 0;
   end record
     with Dynamic_Predicate =>
       Context.First <= Context.Last + 1
       and then Context.First - 1 <= Context.Verified_Last
       and then Context.Verified_Last <= Context.Last;

   function Size (Ctx : Context) return Bit_Length is
     (Ctx.Verified_Last - Ctx.First + 1);

   type Raw_Context is record
      Start     : Bit_Index := 1;
      Last_Read : Bit_Length := 0;
   end record;

   function Pre_Size (Ctx : Raw_Context) return Bit_Length is
     (Ctx.Last_Read - Ctx.Start + 1)
     with Pre => Ctx.Start <= Ctx.Last_Read + 1;

   function Half_Of (X : Natural) return Positive;

   procedure Zero (A : in out Arr64);

   procedure Fill (A : out Arr64; Count : Natural)
     with Pre => Count <= 64;

   function Is_Ok (Data : Byte_Array; Offset : Natural) return Boolean;

   procedure Walk (Data : Byte_Array; Sum : out Natural);

   subtype N32 is I32 range 0 .. I32'Last;
   type Byte_Seq is array (N32 range <>) of Byte;

   --  The loop runs over X'Range: X is not null in its invariant, and its
   --  first bound is an N32.
   function Equal (X, Y : Byte_Seq) return Boolean
     with Pre => X'First = Y'First and then X'Last = Y'Last;

private

   type Ctx_D is record
      First, Last : Natural := 0;
   end record;

   function First_Of (X : Ctx_D) return Natural is (X.First);

end Verification_Contract_Checks;
