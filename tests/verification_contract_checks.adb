--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

package body Verification_Contract_Checks with SPARK_Mode is

   procedure Cases (Bit_Length : Natural; R : out Natural) is
   begin
      R := (if Bit_Length mod 16 = 0 then 0 else 1);
   end Cases;

   procedure Bits_In (Data : Byte_Array; Bit_Len : Natural; R : out Natural)
   is
   begin
      R := Bit_Len;
   end Bits_In;

   function Half_Of (X : Natural) return Positive is
   begin
      return X / 2 + 1;
   end Half_Of;

   procedure Zero (A : in out Arr64) is
   begin
      for J in Index_64 range 0 .. 62 loop
         A (J) := 0;
         pragma Loop_Invariant
           (for all K7 in Index_64 range 0 .. J => A (K7) = 0);
         pragma Loop_Invariant
           (for all K8 in Index_64 range J + 1 .. 63 =>
              A (K8) = A'Loop_Entry (K8));
      end loop;
   end Zero;

   procedure Fill (A : out Arr64; Count : Natural) is
   begin
      A := (others => 0);
      for F1 in Natural range 0 .. Count - 1 loop
         A (I32 (F1)) := 1;
      end loop;
   end Fill;

   function Is_Ok (Data : Byte_Array; Offset : Natural) return Boolean is
   begin
      return Offset <= Data'Length;
   end Is_Ok;

   procedure Walk (Data : Byte_Array; Sum : out Natural) is
      Offset    : Natural := 0;
      Remaining : Natural := Data'Length;
   begin
      Sum := 0;
      while Remaining >= 64 loop
         pragma Loop_Invariant (Offset + Remaining = Data'Length);
         pragma Loop_Invariant (Is_Ok (Data, Offset));
         Offset    := Offset + 64;
         Remaining := Remaining - 64;
      end loop;
   end Walk;

   function Equal (X, Y : Byte_Seq) return Boolean is
      D : Boolean := True;
   begin
      for I in N32 range X'Range loop
         D := D and (X (I) = Y (I));
         pragma Loop_Invariant
           (D = (for all K10 in N32 range X'First .. I => X (K10) = Y (K10)));
      end loop;
      return D;
   end Equal;

end Verification_Contract_Checks;
