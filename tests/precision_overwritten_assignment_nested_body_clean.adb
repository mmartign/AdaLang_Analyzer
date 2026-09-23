procedure Precision_Overwritten_Assignment_Nested_Body_Clean
  (Result : out Integer)
is
   Base : Integer;

   procedure Accumulate is
   begin
      Result := Result + Base;
   end Accumulate;
begin
   Result := 0;
   Base := 1;
   Accumulate;
   Base := 5;
   Accumulate;
end Precision_Overwritten_Assignment_Nested_Body_Clean;
