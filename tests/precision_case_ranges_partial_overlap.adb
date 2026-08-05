procedure Precision_Case_Ranges_Partial_Overlap (X : Integer) is
begin
   case X is
      when 1 .. 5 =>
         null;
      when 3 .. 8 =>
         null;
      when others =>
         null;
   end case;
end Precision_Case_Ranges_Partial_Overlap;
