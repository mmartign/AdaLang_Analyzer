procedure Precision_Case_Ranges_Full_Containment (X : Integer) is
begin
   case X is
      when 1 .. 10 =>
         null;
      when 3 .. 5 =>
         null;
      when others =>
         null;
   end case;
end Precision_Case_Ranges_Full_Containment;
