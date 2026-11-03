--  FP-139: the preservation of a loop invariant was checked with the loop
--  parameter still at the value it had, where the step to the next one
--  could not be told: over "T range L .. H", whose bounds were not read,
--  and over a range with a bound the loop may change. "X = I or else
--  I = 0" holds after "X := I", not on the next iteration.
package Verification_FP139_Loop_Step
  with SPARK_Mode
is
   type I32 is range -2 ** 31 .. 2 ** 31 - 1;
   type Index is range 0 .. 15;

   procedure Constrained (X : in out I32);
   procedure Moving (X : in out I32; N : in out Index);
   procedure Counted (X : out I32);
end Verification_FP139_Loop_Step;
