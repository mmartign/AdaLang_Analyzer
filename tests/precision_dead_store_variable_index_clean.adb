procedure Precision_Dead_Store_Variable_Index_Clean (Result : out Integer) is
   Table : array (0 .. 7) of Integer := (others => 1);
begin
   Table (0 .. 3) := (others => 2);
   Result := 0;
   for I in 0 .. 7 loop
      Result := Result + Table (I);
   end loop;
end Precision_Dead_Store_Variable_Index_Clean;
