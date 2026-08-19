procedure Precision_Address_Clause_At_Finding is
   X : Integer;
   for X use at 16#4000_0000#;
begin
   X := 0;
end Precision_Address_Clause_At_Finding;
