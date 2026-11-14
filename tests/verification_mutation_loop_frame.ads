--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

--  What the frame of a loop does not give (verification_loop_frame has
--  what it does): each check named in quality/verification_mutations.tsv
--  stays unproved, and GNATprove refuses it.
package Verification_Mutation_Loop_Frame with SPARK_Mode is
   type Byte is mod 2 ** 8;
   type Byte_Array is array (Natural range <>) of Byte;
   subtype S64 is Natural range 0 .. 64;
   subtype Zero is Natural range 0 .. 0;

   procedure Assigned (K : S64; R : out S64);        --  the loop assigns RK
   procedure Passed (K : S64; R : out S64);          --  an in out actual
   procedure Nested (K : S64; R : out S64);          --  a nested procedure
   procedure Elements (R : out S64);                 --  elements written
   procedure Written_Bound (N : Natural; R : out Zero)
     with Pre => N = 10;                             --  M written in the loop
   procedure Renamed (K : S64; R : out S64);         --  written by a renaming
   procedure While_Loop (K : S64; R : out S64);      --  a while loop assigns RK

   type Bytes_Ptr is access Byte_Array;
   --  A null designated array: its bounds need not be in Natural.
   function Maybe_Null (P : Bytes_Ptr) return Natural
     with Pre => P /= null;

   type Grid is array (Positive range <>, Natural range <>) of Byte;
   type Grid_Ptr is access Grid;
   --  The second index subtype is Natural, not Positive.
   function Second_First (P : Grid_Ptr) return Positive
     with Pre => P /= null and then P'Length (2) > 0;

   --  Max (A, B) - A need not be 0.
   procedure Max_Diff (A, B : Natural; R : out Zero);

   procedure Inc (X : in out Natural) with Pre => X < Natural'Last;

   procedure Fill_Advance (B : out Byte_Array; Pos : in out Natural)
     with Global => null;
   --  Offset is an actual of its own: the call writes it.
   procedure Advanced (Digest : in out Byte_Array; R : out Zero)
     with Pre => Digest'Length >= 2;

   --  X is written by the summarized loop: its value on entry is gone.
   procedure Counted (N : S64; R : out Zero);
end Verification_Mutation_Loop_Frame;
