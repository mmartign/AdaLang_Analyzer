with System;

procedure Precision_Address_Clause_Aspect_Finding is
   X : Integer with Address => System.Null_Address, Import;
begin
   null;
end Precision_Address_Clause_Aspect_Finding;
