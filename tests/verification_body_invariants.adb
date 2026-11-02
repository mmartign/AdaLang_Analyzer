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
end Verification_Body_Invariants;
