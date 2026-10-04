procedure Precision_Quantified_Expression_Clean is
   type Table is array (1 .. 3) of Integer;
   T : constant Table := (1, 2, 3);
   B : Boolean := True;
begin
   for I in T'Range loop
      B := B and then T (I) > 0;
   end loop;
end Precision_Quantified_Expression_Clean;
