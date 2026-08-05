procedure Precision_Missing_Global_Contract_No_Access_Clean is
   function Compute (X : Integer) return Integer is
   begin
      return X + 1;
   end Compute;

   Result : Integer;
begin
   Result := Compute (5);
end Precision_Missing_Global_Contract_No_Access_Clean;
