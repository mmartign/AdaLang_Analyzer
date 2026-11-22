--  Uninitialized_Read: an index, "A (I)", and the operand of a conversion,
--  "Integer (I)", are read, wherever they are; in a condition they were
--  taken for calls whose formals do not resolve, accesses not known
--  (found with FP-172).

procedure Precision_Uninitialized_Read_Index_Condition_Finding
  (X : out Integer)
is
   type Arr is array (1 .. 10) of Integer;
   A : constant Arr := (others => 0);
   I : Integer;
begin
   X := 0;
   if A (I) > 0 then
      X := 1;
   end if;
end Precision_Uninitialized_Read_Index_Condition_Finding;
