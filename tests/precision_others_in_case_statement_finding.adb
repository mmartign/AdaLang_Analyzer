procedure Precision_Others_In_Case_Statement_Finding (X : Integer) is
   Y : Integer := 0;
begin
   case X is
      when 1 =>
         Y := 1;
      when others =>
         Y := 2;
   end case;
   pragma Assert (Y > 0);
end Precision_Others_In_Case_Statement_Finding;
