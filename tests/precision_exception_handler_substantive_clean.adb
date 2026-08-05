procedure Precision_Exception_Handler_Substantive_Clean is
   Retries : Integer := 0;
begin
   null;
exception
   when Constraint_Error =>
      Retries := Retries + 1;
end Precision_Exception_Handler_Substantive_Clean;
