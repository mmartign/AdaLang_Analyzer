procedure Verification_VC_Runtime_Solver
  (X, Y : Integer;
   Sink : out Integer)
is
   subtype Difference is Integer range -10 .. 0;
   subtype Index is Integer range 0 .. 10;
   type Values is array (Index) of Integer;

   D : Difference;
   A : Values := (others => 0);
begin
   Sink := 0;
   if X >= 0 and then Y <= 10 and then X <= Y then
      D := X - Y;
      Sink := A (X - Y + 10);
   end if;

   if X >= 0 and then Y <= 10 and then X < Y then
      D := Y - X;
      Sink := 1 / (Y - X);
   end if;

   if X ** 2 <= 100 then
      D := X ** 2;
      Sink := A (X ** 2);
      Sink := 1 / (X ** 2);
      Sink := Sink + D;
   end if;
end Verification_VC_Runtime_Solver;
