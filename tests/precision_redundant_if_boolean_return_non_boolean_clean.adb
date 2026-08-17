function Precision_Redundant_If_Boolean_Return_Non_Boolean_Clean
  (X : Integer) return Integer
is
begin
   if X > 0 then
      return 1;
   else
      return 0;
   end if;
end Precision_Redundant_If_Boolean_Return_Non_Boolean_Clean;
