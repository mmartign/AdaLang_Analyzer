--  FP-086: membership in a subtype with a predicate is not a range test.
--  Even holds 0, 2 and 4 only, so "Value not in Even" admits 1, 3 and 5:
--  each division guarded by it can divide by zero and must not be proved.
--  A member of Even is still within 0 .. 10, and a non-member of the
--  predicate-free Small is still outside it, so those two divisions prove.
procedure Verification_FP086_Predicate_Membership
  (Value : Integer;
   Sink  : out Integer)
with SPARK_Mode
is
   subtype Small is Integer range 0 .. 10;
   subtype Even is Small with Static_Predicate => Even in 0 | 2 | 4;
   subtype Even_Alias is Even;
begin
   Sink := 0;
   if Value not in Even then
      Sink := 10 / (Value - 1);
   end if;
   if Value not in Even_Alias then
      Sink := 10 / (Value - 3);
   end if;
   if Value in Small and then Value not in Even then
      Sink := 10 / (Value - 5);
   end if;
   if Value in Even then
      Sink := 10 / (Value - 2);
      Sink := 10 / (Value - 11);
   end if;
   if Value not in Small then
      Sink := 10 / (Value - 7);
   end if;
end Verification_FP086_Predicate_Membership;
