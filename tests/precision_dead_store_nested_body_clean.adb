procedure Precision_Dead_Store_Nested_Body_Clean (Result : out Integer) is
   Base : Integer;

   procedure Compute is
   begin
      Result := Base * 2;
   end Compute;
begin
   Base := 5;
   Compute;
end Precision_Dead_Store_Nested_Body_Clean;
