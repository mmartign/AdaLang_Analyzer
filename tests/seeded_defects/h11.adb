procedure H11 (A, B : Integer; Sink : out Integer)
with Pre => A in 0 .. 1000 and then B in 0 .. 1000
is
   type U32 is mod 2 ** 32;
   UA : constant U32 := U32 (A);
   UB : constant U32 := U32 (B);
   P  : U32 := UA * UB;
   A2 : U32 := UA;
   I  : Integer := 0;
   Q  : U32;
begin
   Sink := 0;
   if A > 0 then
      pragma Assert (P = (UA + 1) * UB);          --  BAD:assertion
   end if;
   if B > 0 then
      pragma Assert (UA * UB = UB * (UA + 1));    --  BAD:assertion
   end if;
   Q := UA * UB;
   A2 := A2 + 1;
   if B > 1 then
      pragma Assert (Q = A2 * UB);                --  BAD:assertion
   end if;
   while I < 3 loop
      pragma Loop_Invariant (P = A2 * UB);        --  BAD:loop-invariant-preservation
      A2 := A2 + 1;
      I := I + 1;
   end loop;
   if A = 65536 then
      null;
   end if;
   Q := U32 (65536 + A) * U32 (65536 + B - B);
   Sink := 10 / Integer (Q mod 1000 + 1);         --  OK
   if A = 0 then
      Sink := 10 / Integer ((U32 (65536) + UA) * (U32 (65536) + UA) + 1);   --  BAD
   end if;
end H11;
