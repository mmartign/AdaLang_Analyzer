package body Verification_Loop_Parameter with SPARK_Mode => On is

   --  An invariant that names the loop parameter holds where an iteration
   --  starts: the parameter is the first value of the range on the first
   --  one, and the value after the one it had on the next. GNATprove
   --  proves both invariants and the postcondition.
   procedure Counted (X : out Integer) is
   begin
      X := 0;
      for I in 0 .. 15 loop
         pragma Loop_Invariant (X = I);
         X := X + 1;
      end loop;
   end Counted;

   procedure Counted_Down (Y : out Integer) is
   begin
      Y := 0;
      for J in reverse 1 .. 8 loop
         pragma Loop_Invariant (Y = 8 - J);
         Y := Y + 1;
      end loop;
   end Counted_Down;

   --  Such an invariant is known where an iteration starts only. The loop
   --  is left with no iteration begun when N = 0, where the assertion
   --  after it fails.
   procedure Empty_Range (N : Natural) is
   begin
      for K in 1 .. N loop
         pragma Loop_Invariant (N > 0);
      end loop;
      pragma Assert (N >= 1);
   end Empty_Range;

   --  Nor is it known where the loop is left after the last iteration:
   --  Z = L - 1 held where that one began, and Z is 10 after it.
   procedure After_Last is
      Z : Integer := 0;
   begin
      for L in 1 .. 10 loop
         pragma Loop_Invariant (Z = L - 1);
         Z := Z + 1;
      end loop;
      pragma Assert (Z <= 9);
   end After_Last;

   --  The range is that of the bounds where the loop is entered: M goes
   --  on to N'Old after N is changed, and the invariant fails on the
   --  second iteration.
   procedure Bound_Changed (N : in out Natural; X : out Natural) is
   begin
      X := 0;
      for M in 0 .. N loop
         pragma Loop_Invariant (M <= N);
         X := X + 1;
         N := 0;
      end loop;
   end Bound_Changed;

end Verification_Loop_Parameter;
