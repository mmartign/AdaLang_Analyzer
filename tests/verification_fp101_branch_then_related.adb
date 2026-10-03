--  FP-101: a branch of two statements made the fixed point reach the
--  statements after the "if" before the branches had been joined, and the
--  second visit joined its state with the first. Objects the two visits
--  disagreed on each got a value of their own, so "Y = X" below was no
--  longer known, its "else" branch was taken to be live, and a division
--  there by a divisor that is always zero was a definite error although
--  it can never run.
procedure Verification_FP101_Branch_Then_Related
  (N    : Integer;
   Sink : out Integer)
with
  SPARK_Mode
is
   X : Integer := N;
   Y : Integer;
begin
   Sink := 0;
   if N > 0 then
      X := X - 5;
      Sink := X;
   end if;

   Y := X + 1;
   X := X + 1;
   if Y = X then
      Sink := 10 / (Y - X + 1);
   else
      Sink := 10 / (N - N);
   end if;

   if Y = 1 then
      Sink := 10 / (X - 1);
   end if;
   if N > 10 then
      Sink := 10 / (N - N - 0);
   end if;
end Verification_FP101_Branch_Then_Related;
