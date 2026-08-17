procedure Precision_Duplicate_Exception_Choice_Clean is
   E1, E2 : exception;
begin
   raise E1;
exception
   when E1 | E2 =>
      null;
end Precision_Duplicate_Exception_Choice_Clean;
