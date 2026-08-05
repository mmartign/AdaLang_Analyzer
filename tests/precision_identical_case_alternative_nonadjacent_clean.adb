procedure Precision_Identical_Case_Alternative_Nonadjacent_Clean
  (X : Integer)
is
   Y : Integer;
begin
   case X is
      when 1 =>
         Y := 10;
      when 2 =>
         Y := 20;
      when others =>
         Y := 10;
   end case;
end Precision_Identical_Case_Alternative_Nonadjacent_Clean;
