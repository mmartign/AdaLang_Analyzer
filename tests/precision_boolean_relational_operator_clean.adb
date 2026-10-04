procedure Precision_Boolean_Relational_Operator_Clean (A, B : in Integer) is
   type Flag is (Off, On);
   F : constant Flag := On;
   Same : constant Boolean := A = B;
   Is_On : constant Boolean := F = On;
begin
   pragma Assert (Same and then Is_On);
end Precision_Boolean_Relational_Operator_Clean;
