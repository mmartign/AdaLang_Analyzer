procedure Precision_Identical_Case_Alternative_Adjacent_Finding
  (X : Integer)
is
   Y : Integer;
begin
   case X is
      when 1 =>
         Y := 10;
      when 2 =>
         Y := 10;
      when others =>
         Y := 0;
   end case;
end Precision_Identical_Case_Alternative_Adjacent_Finding;
