--  FP-093: a function may write whatever it can see. Reset zeroes Level,
--  so a division by Level after any expression that calls Reset can divide
--  by zero, whether the call sits in an assignment, a condition, an
--  initializer or a procedure call's actual. Peek only reads, and leaves
--  what is known about Level and Other in place.
procedure Verification_FP093_Function_Side_Effects
  (N    : Integer;
   Sink : out Integer)
is
   Level : Integer := 5;
   Other : Integer := 5;

   function Reset return Integer is
   begin
      Level := 0;
      return 1;
   end Reset;

   function Peek return Integer is (Other + 1);

   procedure Use_Value (Value : Integer) is null;
begin
   Level := 5;
   Sink := Reset + N;
   Sink := 10 / Level;

   Level := 5;
   if Reset = 1 then
      Sink := 10 / (Level + 0);
   end if;

   Level := 5;
   declare
      Started : constant Integer := Reset;
   begin
      Sink := Started + 10 / (Level - 0);
   end;

   Level := 5;
   Use_Value (Reset);
   Sink := 10 / (0 + Level);

   Level := 5;
   Sink := Reset + 10 / (Level * 1);

   Other := 5;
   Sink := Peek;
   Sink := 10 / Other;
end Verification_FP093_Function_Side_Effects;
