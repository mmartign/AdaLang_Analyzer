--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

--  The frame of a loop, where GNATprove proves the checks: what is known
--  of an object a loop does not write holds in it and after it; a bound
--  of a for loop's range the loop does not write keeps its value on
--  entry; the bounds of an array an access value designates belong to its
--  index subtype; T'Min and T'Max; a call writes the array of a slice or
--  element actual, not what its bounds read; a loop summarized by its
--  proved invariants keeps what holds on every iteration.
--  verification_mutation_loop_frame has what does not hold.
package Verification_Loop_Frame with SPARK_Mode is
   type Byte is mod 2 ** 8;
   type Byte_Array is array (Natural range <>) of Byte;
   type U64 is mod 2 ** 64;
   subtype S64 is Natural range 0 .. 64;

   --  An outer loop's invariant, used inside an inner loop that does not
   --  write Offset.
   procedure Outer_Inner (Data : Byte_Array; Bit_Len : Natural; V : out U64)
     with Pre => Data'Length <= Natural'Last / 8
                 and then Bit_Len <= Data'Length * 8;

   --  What is known of RK before a loop that does not write it, after it.
   procedure Across (A : Byte_Array; K : S64; R : out S64; V : out U64);

   --  A for loop whose bound is a variable the loop does not write.
   procedure Fixed_Bound (A, B : Byte_Array; N : Natural; V : out U64)
     with Pre => A'Length = B'Length and then N <= A'Length;

   --  T'Min.
   procedure Min_Step (Len : Natural; R : out Natural);

   type Bytes_Ptr is access Byte_Array;

   --  The bounds of a designated array that is not null.
   function First_Of (P : Bytes_Ptr) return Natural
     with Pre => P /= null and then P'Length > 0;

   procedure Fill (B : out Byte_Array)
     with Global => null, Post => True;

   --  A call writes a slice of Digest; Offset and Rate, read by its
   --  bounds, keep their values.
   procedure Squeeze (Digest : in out Byte_Array; Rate : Positive)
     with Pre => Digest'Last < Natural'Last;

   --  A loop summarized by its proved invariant keeps the precondition's
   --  facts on Digest's bounds.
   procedure Summarized (Digest : Byte_Array; Rate : Positive; V : out Byte)
     with Pre => Digest'Last < Natural'Last;
end Verification_Loop_Frame;
