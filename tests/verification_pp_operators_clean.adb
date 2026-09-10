--  Proof-path evidence: scalar VC operator sub-boundaries that must each
--  reach Proved_Safe. One obligation per supported operator family.
procedure Verification_PP_Operators_Clean
  (A : Integer;
   B : Integer;
   Sink : out Integer)
with SPARK_Mode,
     Pre => A in 0 .. 100 and then B in 1 .. 100
is
begin
   Sink := 0;

   --  multiplication overflow obligation
   pragma Assert (A * B >= 0);

   --  unary negation
   pragma Assert (-A <= 0);

   --  boolean 'not' and connectives
   pragma Assert (not (A > 100));
   pragma Assert (A >= 0 and then B >= 1);
   pragma Assert (A > 100 or else B <= 100);

   --  comparison operators
   pragma Assert (A <= 100);
   pragma Assert (B /= 0);

   --  division / mod / rem with a provably non-zero divisor
   Sink := A / B;
   Sink := A mod B;
   Sink := A rem B;
end Verification_PP_Operators_Clean;
