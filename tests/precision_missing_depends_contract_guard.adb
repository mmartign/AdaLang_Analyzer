procedure Precision_Missing_Depends_Contract_Guard is
   procedure Compute (X : Integer; Y : out Integer) is
   begin
      Y := X + 1;
   end Compute;

   Result : Integer;
begin
   Compute (5, Result);
end Precision_Missing_Depends_Contract_Guard;
