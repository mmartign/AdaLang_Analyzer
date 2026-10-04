procedure Precision_Membership_Test_Finding (X : Integer) is
   B : constant Boolean := X in 1 .. 10;
begin
   pragma Assert (B);
end Precision_Membership_Test_Finding;
