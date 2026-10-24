--  The head of the second loop is reached before the first loop has
--  settled: first with S = 0 and T = 0, then with S and T in 0 .. 1.
--  Widening what the edge into the loop brings would give up the bounds of
--  S and T, which the second loop does not write, and the sum after it
--  would no longer be shown not to overflow.
procedure Verification_Loop_Entry_Widening
  (N    : Integer;
   A, B : Boolean;
   Sink : out Integer)
  with SPARK_Mode,
       Pre => N in 0 .. 100
is
   S : Integer := 0;
   T : Integer := 0;
   W : Integer := 0;
begin
   for I in 1 .. N loop
      pragma Loop_Invariant (S in 0 .. 1 and then T in 0 .. 1);
      if A then S := 1; else S := 0; end if;
      if B then T := 1; else T := 0; end if;
   end loop;

   for I in 1 .. N loop
      pragma Loop_Invariant (W in 0 .. 1);
      if A then
         if B then W := 1; else W := 0; end if;
      end if;
   end loop;

   Sink := S + T + W;
end Verification_Loop_Entry_Widening;
