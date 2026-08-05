procedure Precision_Function_Side_Effect_Local_Clean is
   function Compute (X : Integer) return Integer is
      Local : Integer;
   begin
      Local := X + 1;
      return Local;
   end Compute;

   Result : Integer;
begin
   Result := Compute (5);
end Precision_Function_Side_Effect_Local_Clean;
