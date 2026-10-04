procedure Precision_Binary_Case_Statement_Clean (X : Integer) is
   Y : Integer := 0;
begin
   case X is
      when 1 | 2 =>
         Y := 1;
      when others =>
         Y := 2;
   end case;
   case X is
      when 1 =>
         Y := 1;
      when 2 =>
         Y := 2;
      when others =>
         Y := 3;
   end case;
   pragma Assert (Y > 0);
end Precision_Binary_Case_Statement_Clean;
