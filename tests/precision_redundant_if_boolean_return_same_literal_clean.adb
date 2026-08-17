function Precision_Redundant_If_Boolean_Return_Same_Literal_Clean
  (X : Integer) return Boolean
is
begin
   if X > 0 then
      return True;
   else
      return True;
   end if;
end Precision_Redundant_If_Boolean_Return_Same_Literal_Clean;
