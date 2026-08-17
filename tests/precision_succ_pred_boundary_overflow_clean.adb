procedure Precision_Succ_Pred_Boundary_Overflow_Clean is
   type Day is (Mon, Tue, Wed, Thu, Fri, Sat, Sun);
   D : Day := Day'Succ (Mon);
begin
   null;
end Precision_Succ_Pred_Boundary_Overflow_Clean;
