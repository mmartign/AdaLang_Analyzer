procedure Verification_Length_Attribute_Unsound
  (Chain : in out String)
is
begin
   pragma Assert (Chain'Length >= 0);
   pragma Assert (Chain'Length >= 1);
end Verification_Length_Attribute_Unsound;
