procedure Precision_Quantified_Expression_Finding is
   type Table is array (1 .. 3) of Integer;
   T : constant Table := (1, 2, 3);
   B : constant Boolean := (for all I in T'Range => T (I) > 0);
begin
   pragma Assert (B);
end Precision_Quantified_Expression_Finding;
