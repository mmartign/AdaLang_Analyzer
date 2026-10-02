--  FP-090: a symbol minted where paths merge must cover every value that
--  reaches the merge, not only those of the first visit. Each loop below
--  changes a variable on some iterations only, so after the loop it may be
--  zero and the division must not be proved. Kept is never assigned in a
--  loop and still proves.
procedure Verification_FP090_Loop_Exit_Roots
  (N    : Integer;
   Sink : out Integer)
is
   Early : Integer := 5;
   Late  : Integer := 5;
   Count : Integer := 0;
   Kept  : Integer := 5;
begin
   for I in 1 .. N loop
      exit when I > 3;
      Early := 0;
   end loop;
   Sink := 10 / Early;

   for J in 1 .. 3 loop
      if J = 3 and then N > 0 then
         Late := 0;
      end if;
   end loop;
   Sink := 10 / Late;

   for K in 1 .. 10 loop
      Count := Count + 1;
      exit when K = N;
   end loop;
   Sink := 10 / (Count - 3);

   Sink := 10 / Kept;
end Verification_FP090_Loop_Exit_Roots;
