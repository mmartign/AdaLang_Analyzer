procedure Precision_Binary_Case_Statement_Finding (B : Boolean) is
   Y : Integer := 0;
begin
   case B is
      when True =>
         Y := 1;
      when False =>
         Y := 2;
   end case;
   pragma Assert (Y > 0);
end Precision_Binary_Case_Statement_Finding;
