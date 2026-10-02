package body H12 is
   procedure Q01 (N : Integer; Sink : out Integer) is
   begin
      G := 5;
      H12.G := N - N;
      Sink := 10 / G;                    --  BAD
   end Q01;

   procedure Q02 (N : Integer; Sink : out Integer) is
   begin
      H12.G := 5;
      G := N - N;
      Sink := 10 / H12.G;                --  BAD
   end Q02;

   procedure Q03 (N : Integer; Sink : out Integer) is
   begin
      H12.G := 5;
      Sink := 10 / H12.G + N;            --  OK
      if H12.G > 3 then
         Sink := 10 / (H12.G - 3);       --  OK
      end if;
   end Q03;

   procedure Q04 (N : Integer; Sink : out Integer) is
   begin
      Inner.V := 5;
      H12.Inner.V := N - N;
      Sink := 10 / Inner.V;              --  BAD
   end Q04;

   procedure Q05 (N : Integer; Sink : out Integer) is
   begin
      R.F := 5;
      H12.R.F := N - N;
      Sink := 10 / R.F;                  --  BAD
   end Q05;

   procedure Q06 (N : Integer; Sink : out Integer) is
   begin
      Sink := N;
      if H12.G in 1 .. 5 then
         Sink := 10 / H12.G;             --  OK
         Sink := 10 / (G - 5);           --  BAD
      end if;
      if G > 0 then
         H12.G := H12.G - 1;
         Sink := 10 / G;                 --  BAD
      end if;
   end Q06;
end H12;
