procedure Precision_Assertion_Side_Effect_Clean is

   function Is_Positive (X : Integer) return Boolean is (X > 0);

   X : Integer := 5;
begin
   pragma Assert (Is_Positive (X));
end Precision_Assertion_Side_Effect_Clean;
