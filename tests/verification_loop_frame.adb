--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

package body Verification_Loop_Frame with SPARK_Mode is

   procedure Outer_Inner (Data : Byte_Array; Bit_Len : Natural; V : out U64)
   is
      Remaining : Natural := Bit_Len;
      Offset    : Natural := 0;
   begin
      V := 0;
      for Y in 0 .. 4 loop
         pragma Loop_Invariant (Offset * 8 + Remaining = Bit_Len);
         exit when Remaining < 64;
         for I in 0 .. 7 loop
            V := V + U64 (Data (Data'First + Offset + I));
         end loop;
         Offset    := Offset + 8;
         Remaining := Remaining - 64;
      end loop;
   end Outer_Inner;

   procedure Across (A : Byte_Array; K : S64; R : out S64; V : out U64) is
      RK : Natural;
   begin
      V := 0;
      RK := 64 - K;
      for I in 0 .. 3 loop
         V := V + 1;
      end loop;
      R := K + RK;
   end Across;

   procedure Fixed_Bound (A, B : Byte_Array; N : Natural; V : out U64) is
      M : Natural := N;
   begin
      V := 0;
      for I in 0 .. M - 1 loop
         V := V + U64 (A (A'First + I)) + U64 (B (B'First + I));
      end loop;
   end Fixed_Bound;

   procedure Min_Step (Len : Natural; R : out Natural) is
      Left : Natural := Len;
      Step : Natural;
   begin
      R := 0;
      while Left > 0 loop
         Step := Natural'Min (Left, 4);
         Left := Left - Step;
         R := R + 1;
         exit when R = Natural'Last;
      end loop;
   end Min_Step;

   function First_Of (P : Bytes_Ptr) return Natural is (P'First);

   procedure Fill (B : out Byte_Array) is
   begin
      B := (others => 0);
   end Fill;

   procedure Squeeze (Digest : in out Byte_Array; Rate : Positive) is
      Remaining : Natural := Digest'Length;
      Offset    : Natural := 0;
   begin
      while Remaining >= Rate loop
         pragma Loop_Invariant (Offset + Remaining = Digest'Length);
         Fill (Digest (Digest'First + Offset ..
                       Digest'First + Offset + (Rate - 1)));
         Offset    := Offset + Rate;
         Remaining := Remaining - Rate;
      end loop;
   end Squeeze;

   procedure Summarized (Digest : Byte_Array; Rate : Positive; V : out Byte)
   is
      Remaining : Natural := Digest'Length;
      Offset    : Natural := 0;
   begin
      V := 0;
      while Remaining >= Rate loop
         pragma Loop_Invariant (Offset + Remaining = Digest'Length);
         V := V xor Digest (Digest'First + Offset);
         Offset    := Offset + Rate;
         Remaining := Remaining - Rate;
      end loop;
   end Summarized;
end Verification_Loop_Frame;
