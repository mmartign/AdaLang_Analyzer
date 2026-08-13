procedure Verification_Proof_Paths_Abstract
  (Sink : out Integer)
with SPARK_Mode,
     Post => Sink = 5
is
   subtype Small is Integer range 0 .. 10;

   procedure Require_Positive (Value : Integer)
     with Pre => Value > 0
   is
   begin
      null;
   end Require_Positive;

   V : Small := 1;
begin
   Require_Positive (V);
   pragma Assert (V >= 0);
   Sink := 10 / 2;
end Verification_Proof_Paths_Abstract;
