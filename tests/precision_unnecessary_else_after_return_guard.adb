procedure Precision_Unnecessary_Else_After_Return_Guard is
   function Compute (X : Integer) return Integer is
   begin
      if X > 0 then
         return X;
      else
         return -X;
      end if;
   end Compute;

   Result : Integer;
begin
   Result := Compute (5);
end Precision_Unnecessary_Else_After_Return_Guard;
