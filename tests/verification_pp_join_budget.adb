--  Proof-path evidence: join sub-boundary beyond the first conditional.
--  Loop-invariant preservation folds a second independent conditional,
--  sequential or nested; a third along one path exhausts the branch budget
--  and stays Unproved with branch-budget-exceeded provenance. A second
--  conditional that breaks the invariant is never proved.
procedure Verification_PP_Join_Budget
  (N : Integer;
   A, B, C : Boolean;
   Sink : out Integer)
with SPARK_Mode,
     Pre => N in 0 .. 100
is
   S : Integer := 0;
   T : Integer := 0;
   U : Integer := 0;
   W : Integer := 0;
begin
   for I in 1 .. N loop
      pragma Loop_Invariant (S in 0 .. 1 and then T in 0 .. 1);
      if A then S := 1; else S := 0; end if;
      if B then T := 1; else T := 0; end if;
   end loop;

   for I in 1 .. N loop
      pragma Loop_Invariant (U in 0 .. 1);
      if A then U := 1; else U := 0; end if;
      if B then U := U + 1; end if;
   end loop;

   for I in 1 .. N loop
      pragma Loop_Invariant (T in 0 .. 1 and then S in 0 .. 1);
      if A then S := 1; else S := 0; end if;
      if B then T := 1; else T := 0; end if;
      if C then S := 0; end if;
   end loop;

   W := 0;
   for I in 1 .. N loop
      pragma Loop_Invariant (W >= 0 and then W <= 1);
      if A then
         if B then W := 1; else W := 0; end if;
      end if;
   end loop;

   for I in 1 .. N loop
      pragma Loop_Invariant (W <= 1 and then W >= 0);
      if A then
         if B then
            if C then W := 1; else W := 0; end if;
         end if;
      end if;
   end loop;

   Sink := S + T + U + W;
end Verification_PP_Join_Budget;
