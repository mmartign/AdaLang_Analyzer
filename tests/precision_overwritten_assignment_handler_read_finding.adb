--  At the same shape, the first value is lost when nothing between the two
--  writes can raise, and when no handler reads the target.
procedure Precision_Overwritten_Assignment_Handler_Read_Finding
  (N : Natural; Ok : out Boolean)
is
   A      : array (1 .. 4) of Natural := [others => 0];
   Locked : Boolean := False;
   Count  : Natural := 0;
   Step   : Natural := 0;
begin
   Locked := True;
   Count := 0;
   Locked := False;
   Step := 1;
   for I in 1 .. N loop
      A (I) := I;
   end loop;
   Step := 2;
   Ok := Locked or else Count + Step > 0;
exception
   when Constraint_Error =>
      if Locked then
         Ok := False;
      end if;
      Ok := False;
end Precision_Overwritten_Assignment_Handler_Read_Finding;
