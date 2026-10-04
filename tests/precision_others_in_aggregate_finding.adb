procedure Precision_Others_In_Aggregate_Finding is
   type Table is array (1 .. 10) of Integer;
   A : constant Table := (1 .. 3 => 1, others => 0);
   B : constant Table := (1 => 1, 2 => 2, others => 0);
   C : constant Table := (1 | 2 => 1, others => 0);
begin
   pragma Assert (A (1) = B (1) and then B (1) = C (1));
end Precision_Others_In_Aggregate_Finding;
