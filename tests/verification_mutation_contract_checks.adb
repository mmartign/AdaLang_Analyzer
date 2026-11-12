--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

package body Verification_Mutation_Contract_Checks with SPARK_Mode is

   procedure Cases (Bit_Length, Div : Natural; R : out Natural) is
   begin
      R := (if Bit_Length = 0 and then Div = 0 then 0 else 1);
   end Cases;

   procedure Bits_In (Data : Wide_Array; Bit_Len : Natural; R : out Natural)
   is
   begin
      R := Bit_Len;
   end Bits_In;

   procedure Spread (A : in out Arr64; Lim : I32) is
   begin
      for J in Index_64 range 0 .. 62 loop
         A (J) := 0;
         pragma Loop_Invariant
           (for all K4 in Index_64 range J .. Lim => A (K4) = A (K4));
      end loop;
   end Spread;

   procedure Count_Up (A : out Arr16; N : I32) is
   begin
      A := (others => 0);
      for L1 in Index_16 range 0 .. N loop
         A (L1) := 1;
      end loop;
   end Count_Up;

   function Is_Ok (Data : Wide_Array; Offset : Natural) return Boolean is
   begin
      return Offset <= Data'Length;
   end Is_Ok;

   procedure Grow (Data : Wide_Array; Sum : out Natural) is
      Offset    : Natural := 0;
      Remaining : Natural := 100;
   begin
      Sum := 0;
      while Remaining >= 64 loop
         pragma Loop_Invariant (Offset + Remaining >= 100);
         pragma Loop_Invariant (Is_Ok (Data, Offset));
         Offset    := (if Offset < Natural'Last - 64 then Offset + 64
                       else Offset);
         Remaining := Remaining - 1;
      end loop;
   end Grow;

   function Other_First (X, Y : Byte_Seq) return Boolean is
      D : Boolean := True;
   begin
      for I in N32 range Y'Range loop
         D := D and (Y (I) = 0);
         pragma Loop_Invariant
           (for all K11 in N32 range X'First .. I => K11 >= 0);
      end loop;
      return D;
   end Other_First;

end Verification_Mutation_Contract_Checks;
