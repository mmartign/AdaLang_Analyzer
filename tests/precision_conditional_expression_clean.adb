procedure Precision_Conditional_Expression_Clean (X : Integer) is
   Y : Integer := 0;
begin
   if X > 0 then
      Y := 1;
   end if;
   case Y is
      when 0 =>
         Y := 5;
      when others =>
         Y := 6;
   end case;
end Precision_Conditional_Expression_Clean;
