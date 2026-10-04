procedure Precision_Membership_Test_Clean (X : Integer) is
   B : constant Boolean := X >= 1 and then X <= 10;
begin
   for I in 1 .. 10 loop
      pragma Assert (B or else I > 0);
   end loop;
end Precision_Membership_Test_Clean;
