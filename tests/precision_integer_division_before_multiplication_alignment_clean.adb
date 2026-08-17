procedure Precision_Integer_Division_Before_Multiplication_Alignment_Clean is
   Addr      : Integer := 4103;
   Alignment : constant Integer := 8;
   Aligned   : Integer;
begin
   Aligned := Addr / Alignment * Alignment;
end Precision_Integer_Division_Before_Multiplication_Alignment_Clean;
