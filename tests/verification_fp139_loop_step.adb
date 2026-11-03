package body Verification_FP139_Loop_Step
  with SPARK_Mode
is
   procedure Constrained (X : in out I32) is
   begin
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant (X = I32 (I) or else I = 0);
         X := I32 (I);
      end loop;
   end Constrained;

   procedure Moving (X : in out I32; N : in out Index) is
   begin
      for I in Index range 0 .. N loop
         pragma Loop_Invariant (X = I32 (I) + 1 or else I = 0);
         X := I32 (I) + 1;
         N := N;
      end loop;
   end Moving;

   procedure Counted (X : out I32) is
   begin
      X := 0;
      for I in Index range 0 .. 7 loop
         pragma Loop_Invariant (X = I32 (I));
         X := X + 1;
      end loop;
   end Counted;
end Verification_FP139_Loop_Step;
