procedure Precision_Universal_Range_Finding is
   Limit : constant := 4;
   Table : array (1 .. Limit) of Integer := (others => 0);
begin
   for I in 1 .. 4 loop
      Table (I) := I;
   end loop;
end Precision_Universal_Range_Finding;
