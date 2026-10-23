package body Verification_FP129_Summarized_Loop with SPARK_Mode => On is

   procedure Incr (X : in out Integer) is
   begin
      X := X + 1;
   end Incr;

   procedure Bump is
   begin
      G := G + 1;
   end Bump;

   --  A loop whose invariants are proved is summarized by them on the
   --  second run. An object it writes only through a call, or only in a
   --  loop nested in it, has another value after it: every assertion
   --  "... = 0" fails. Kept is written by none of them. The invariant of
   --  By_Inner_Loop is not proved yet (the preservation walk stops at a
   --  nested loop): it is there for when it is.

   procedure By_Call_In_For is
      X    : Integer := 0;
      Kept : constant Integer := 5;
   begin
      for I in 1 .. 10 loop
         pragma Loop_Invariant (X = I - 1);
         Incr (X);
      end loop;
      pragma Assert (X = 0);
      pragma Assert (Kept = 5);
   end By_Call_In_For;

   procedure By_Call_In_While is
      X    : Integer := 0;
      C    : Natural := 0;
      Kept : Integer := 5;
   begin
      while C < 10 loop
         pragma Loop_Invariant (C <= 10);
         pragma Loop_Invariant (X <= C);
         Incr (X);
         C := C + 1;
      end loop;
      pragma Assert (X = 0);
      pragma Assert (Kept = 5);
   end By_Call_In_While;

   procedure By_Global is
      C : Natural := 0;
   begin
      G := 0;
      while C < 10 loop
         pragma Loop_Invariant (C <= 10);
         Bump;
         C := C + 1;
      end loop;
      pragma Assert (G = 0);
   end By_Global;

   procedure By_Inner_Loop is
      X : Integer := 0;
      C : Natural := 0;
   begin
      while C < 10 loop
         pragma Loop_Invariant (C <= 10);
         for J in 1 .. 2 loop
            X := J;
         end loop;
         C := C + 1;
      end loop;
      pragma Assert (X = 0);
   end By_Inner_Loop;

end Verification_FP129_Summarized_Loop;
