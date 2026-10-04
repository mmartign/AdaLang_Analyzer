procedure Precision_Others_In_Exception_Handler_Finding is
   X : Integer := 0;
begin
   X := X + 1;
exception
   when others =>
      X := 0;
end Precision_Others_In_Exception_Handler_Finding;
