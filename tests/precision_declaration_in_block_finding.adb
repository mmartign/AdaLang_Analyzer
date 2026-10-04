procedure Precision_Declaration_In_Block_Finding is
   Total : Integer := 0;
begin
   declare
      Copy : constant Integer := Total;
   begin
      Total := Copy + 1;
   end;
end Precision_Declaration_In_Block_Finding;
