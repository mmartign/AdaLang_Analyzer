with System;

procedure Precision_Address_Clause_Finding is
   X : Integer;
   for X'Address use System.Null_Address;
begin
   X := 0;
end Precision_Address_Clause_Finding;
