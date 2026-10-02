--  A membership test narrows the tested identifier's interval. The member
--  side takes the hull of the alternatives; the non-member side can only
--  drop an alternative that covers an end of the interval already known,
--  and never one given by a subtype with a predicate.
procedure Verification_Membership_Narrowing
  (Free    : Integer;
   Bounded : Integer;
   Divisor : Integer;
   Limit   : Integer;
   Sink    : out Integer)
with
  SPARK_Mode,
  Pre => Bounded in 0 .. 10 and then Divisor in 1 .. 5
is
   subtype Small is Integer range 0 .. 10;
   subtype Even is Small with Static_Predicate => Even in 0 | 2 | 4;
begin
   Sink := 100 / Divisor;

   if Free in 1 | 5 then
      Sink := 10 / Free;
      Sink := 10 / (Free - 5);
   end if;
   if Free in Small then
      Sink := 10 / (Free - 11);
      Sink := 10 / (Free - 9);
   end if;
   if Free in 1 .. Limit then
      Sink := 10 / (Free + 1);
      Sink := 10 / (Free - 20);
   end if;
   if Free not in 3 .. 5 then
      Sink := 10 / (Free - 7);
   end if;

   if Bounded not in 0 .. 3 then
      Sink := 10 / (Bounded - 2);
      Sink := 10 / (Bounded - 8);
   end if;
   if Bounded not in 4 .. 6 | 0 .. 3 then
      Sink := 10 / (Bounded - 6);
   end if;
   if Bounded not in 3 .. 5 then
      Sink := 10 / (Bounded - 1);
   end if;
   if Bounded not in Even then
      Sink := 10 / (Bounded - 3);
   end if;
   if Bounded in Small then
      Sink := 10 / (Bounded + 1);
   else
      Sink := 10 / (Bounded - 4);
   end if;
end Verification_Membership_Narrowing;
