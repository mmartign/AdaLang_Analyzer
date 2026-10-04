procedure Precision_Others_In_Exception_Handler_Clean (S : Boolean) is
   X : Integer := 0;
begin
   case S is
      when True =>
         X := X + 1;
      when others =>
         X := X + 2;
   end case;
exception
   when Constraint_Error =>
      X := 0;
end Precision_Others_In_Exception_Handler_Clean;
