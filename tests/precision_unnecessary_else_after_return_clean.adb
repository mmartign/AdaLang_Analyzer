procedure Precision_Unnecessary_Else_After_Return_Clean is
   function Compute (X : Integer) return Integer is
      Y : Integer;
   begin
      if X > 0 then
         Y := X;
      else
         Y := -X;
      end if;
      return Y;
   end Compute;

   Result : Integer;
begin
   Result := Compute (5);
end Precision_Unnecessary_Else_After_Return_Clean;
