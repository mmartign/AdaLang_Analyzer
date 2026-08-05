procedure Precision_Check_Policy_On_Clean is
   pragma Check_Policy (Assertion, On);
   X : Integer := 0;
begin
   X := X + 1;
end Precision_Check_Policy_On_Clean;
