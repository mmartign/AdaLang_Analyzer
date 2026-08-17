procedure Precision_Duplicate_Exception_Choice_Finding is
   E1, E2 : exception;
begin
   raise E1;
exception
   when E1 | E1 =>
      null;
end Precision_Duplicate_Exception_Choice_Finding;
