--  FP-098: a loop over an empty range never runs, and what its body would
--  have done says nothing about the code after it. Kept is still 1 after
--  each loop below, so "Kept - 1" divides by zero, and Divisor is whatever
--  the caller passed.
procedure Verification_FP098_Infeasible_Roots
  (Divisor : Integer;
   Sink    : out Integer)
is
   Kept : Integer := 1;
begin
   for I in 1 .. 0 loop
      Kept := I;
   end loop;
   Sink := 10 / (Kept - 1);
   Sink := 10 / Divisor;

   for K in reverse 5 .. 1 loop
      Kept := K;
   end loop;
   Sink := 10 / (Divisor - 1);
   Sink := 10 / (Kept + 1);
end Verification_FP098_Infeasible_Roots;
