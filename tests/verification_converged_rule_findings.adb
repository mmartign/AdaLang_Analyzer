--  Rule findings under --verify come from converged states only. Before
--  the loops below have been taken into account, Count is 0 and Limit is
--  10, which makes "10 / Count" a division by a known zero and "Count <
--  Limit" a constant condition; neither is true of the program. A divisor
--  and a condition that no path changes are still reported.
procedure Verification_Converged_Rule_Findings
  (N    : Integer;
   Sink : out Integer)
is
   Count : Integer := 0;
   Limit : constant Integer := 10;
   Fixed : Integer := 0;
begin
   for I in 1 .. N loop
      Count := Count + 1;
   end loop;
   Sink := 10 / Count;

   Count := 0;
   while Count < Limit loop
      Count := Count + 1;
   end loop;

   if Fixed = 0 then
      Sink := Sink + 1;
   end if;
   Sink := 10 / Fixed;
end Verification_Converged_Rule_Findings;
