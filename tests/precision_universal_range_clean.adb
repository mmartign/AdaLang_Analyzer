procedure Precision_Universal_Range_Clean is
   type Index is range 1 .. 4;
   type Table_Type is array (Index) of Integer;
   Table : Table_Type := (others => 0);
begin
   for I in Index loop
      Table (I) := Integer (I);
   end loop;
   for I in Index range 1 .. 2 loop
      Table (I) := 0;
   end loop;
end Precision_Universal_Range_Clean;
