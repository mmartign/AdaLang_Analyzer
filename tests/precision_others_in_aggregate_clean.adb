procedure Precision_Others_In_Aggregate_Clean is
   type Table is array (1 .. 10) of Integer;
   A : constant Table := (others => 0);
   B : constant Table := (1 => 1, others => 0);
begin
   pragma Assert (A (2) = B (2));
end Precision_Others_In_Aggregate_Clean;
