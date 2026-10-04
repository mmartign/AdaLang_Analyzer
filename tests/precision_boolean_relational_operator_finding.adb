procedure Precision_Boolean_Relational_Operator_Finding (A, B : in Boolean) is
   Same : constant Boolean := A = B;
   Less : constant Boolean := A < B;
begin
   pragma Assert (Same or else Less);
end Precision_Boolean_Relational_Operator_Finding;
