procedure H14 (N : Integer; M : Integer; Sink : out Integer) is
   subtype Small is Integer range 0 .. 5;
   X : Integer := 1;
   Y : Integer := 1;
   Z : Integer := 1;
   S : Small := 2;
begin
   for I in 1 .. 0 loop
      X := I;
   end loop;
   Sink := 10 / (X - 1);              --  BAD
   if S > 3 and S < 2 then
      Y := S;
   end if;
   Sink := 10 / (Y - 1);              --  BAD
   if N > 3 and N < 2 then
      pragma Assert (N > 0);
      Z := N;
   end if;
   Sink := 10 / (Z - 1);              --  BAD
   Sink := 10 / M;                    --  BAD
   for K in reverse 5 .. 1 loop
      Z := K;
   end loop;
   Sink := 10 / (M - 1);              --  BAD
end H14;
