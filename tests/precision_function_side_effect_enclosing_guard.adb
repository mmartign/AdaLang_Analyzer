procedure Precision_Function_Side_Effect_Enclosing_Guard is
   Counter : Integer := 0;

   function Compute (X : Integer) return Integer is
   begin
      Counter := Counter + 1;
      return X;
   end Compute;

   Result : Integer;
begin
   Result := Compute (5);
end Precision_Function_Side_Effect_Enclosing_Guard;
