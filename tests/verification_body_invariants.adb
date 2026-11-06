package body Verification_Body_Invariants
  with SPARK_Mode
is
   procedure Constant_Value is
      X : Integer := 0;
   begin
      for K in 1 .. 10 loop
         X := 5;
         pragma Loop_Invariant (X = 5);
      end loop;
   end Constant_Value;

   procedure Bounded_Value is
      X : Integer := 0;
   begin
      for K in 1 .. 10 loop
         X := K;
         pragma Loop_Invariant (X in 1 .. 10);
      end loop;
   end Bounded_Value;

   procedure Related_Value (A : Integer) is
      Y : Integer := 0;
   begin
      for K in 1 .. 10 loop
         Y := A + K;
         pragma Loop_Invariant (Y = A + K);
      end loop;
   end Related_Value;

   --  True by induction only.
   procedure Counted is
      S : Integer := 0;
   begin
      for K in 1 .. 10 loop
         S := S + 1;
         pragma Loop_Invariant (S = K);
      end loop;
   end Counted;

   procedure Progress is
      N : Integer := 10;
      C : Integer := 0;
   begin
      while N > 0 loop
         N := N - 1;
         pragma Loop_Invariant (N + C + 1 = 10);
         C := C + 1;
      end loop;
   end Progress;

   procedure Progress_With_Exit is
      N : Integer := 10;
      C : Integer := 0;
   begin
      while N > 0 loop
         N := N - 1;
         pragma Loop_Invariant (C + N + 1 = 10);
         exit when C = 5;
         C := C + 1;
      end loop;
   end Progress_With_Exit;

   procedure Entered_Again is
      N, C : Integer;
   begin
      for J in 1 .. 3 loop
         N := 10;
         C := 0;
         while N > 0 loop
            N := N - 1;
            pragma Loop_Invariant (N + 1 + C = 10);
            C := C + 1;
         end loop;
      end loop;
   end Entered_Again;

   --  Kept by an iteration only through what is assumed on the way.
   procedure Assumed_Step (A : Values) is
      S : Integer := 0;
      T : Integer;
   begin
      for K in A'Range loop
         T := A (K);
         pragma Assume (T in 0 .. 1);
         S := S + T;
         pragma Loop_Invariant (S <= K);
      end loop;
   end Assumed_Step;
end Verification_Body_Invariants;
