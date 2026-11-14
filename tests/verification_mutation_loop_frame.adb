--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

package body Verification_Mutation_Loop_Frame with SPARK_Mode is

   procedure Inc (X : in out Natural) is
   begin
      X := X + 1;
   end Inc;

   procedure Assigned (K : S64; R : out S64) is
      RA : Natural := 64 - K;
   begin
      for I in 0 .. 3 loop
         RA := RA + 1;
      end loop;
      R := K + RA;
   end Assigned;

   procedure Passed (K : S64; R : out S64) is
      RP : Natural := 64 - K;
   begin
      for I in 0 .. 3 loop
         Inc (RP);
      end loop;
      R := K + RP;
   end Passed;

   procedure Nested (K : S64; R : out S64) is
      RN : Natural := 64 - K;
      procedure Bump is
      begin
         if RN < 100 then
            RN := RN + 1;
         end if;
      end Bump;
   begin
      for I in 0 .. 3 loop
         Bump;
      end loop;
      R := K + RN;
   end Nested;

   procedure Elements (R : out S64) is
      A : Byte_Array (0 .. 3) := (others => 0);
   begin
      for I in A'Range loop
         A (I) := 255;
      end loop;
      R := S64 (A (0));
   end Elements;

   procedure Written_Bound (N : Natural; R : out Zero) is
      M : Natural := N - 1;
   begin
      R := 0;
      for I in 0 .. M loop
         M := 0;
         R := I;
      end loop;
   end Written_Bound;

   procedure Renamed (K : S64; R : out S64) is
      RM : Natural := 64 - K;
      RR : Natural renames RM;
   begin
      for I in 0 .. 3 loop
         RR := RR + 1;
      end loop;
      R := K + RM;
   end Renamed;

   procedure While_Loop (K : S64; R : out S64) is
      RW : Natural := 64 - K;
      J  : Natural := 0;
   begin
      while J < 4 loop
         RW := RW + 1;
         J := J + 1;
      end loop;
      R := K + RW;
   end While_Loop;

   function Maybe_Null (P : Bytes_Ptr) return Natural is (P'First);

   function Second_First (P : Grid_Ptr) return Positive is (P'First (2));

   procedure Max_Diff (A, B : Natural; R : out Zero) is
   begin
      R := Natural'Max (A, B) - A;
   end Max_Diff;

   procedure Fill_Advance (B : out Byte_Array; Pos : in out Natural) is
   begin
      B := (others => 0);
      if Pos < Natural'Last then
         Pos := Pos + 1;
      end if;
   end Fill_Advance;

   procedure Advanced (Digest : in out Byte_Array; R : out Zero) is
      Offset : Natural := 0;
   begin
      Fill_Advance (Digest (Digest'First .. Digest'First), Offset);
      R := Offset;
   end Advanced;

   procedure Counted (N : S64; R : out Zero) is
      X : Natural := 0;
      J : Natural := 0;
   begin
      while J < N loop
         pragma Loop_Invariant (J <= N and then X = J);
         X := X + 1;
         J := J + 1;
      end loop;
      R := X;
   end Counted;
end Verification_Mutation_Loop_Frame;
