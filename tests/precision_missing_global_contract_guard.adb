procedure Precision_Missing_Global_Contract_Guard is
   Counter : Integer := 0;

   procedure Bump is
   begin
      Counter := Counter + 1;
   end Bump;
begin
   Bump;
end Precision_Missing_Global_Contract_Guard;
