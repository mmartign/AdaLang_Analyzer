--  FP-132: a body declared in the block reads the local between the two
--  assignments, so the earlier value is read before it is overwritten.
procedure Precision_Overwritten_Assignment_Block_Nested_Body_Clean
  (Result : out Integer)
is
begin
   Result := 0;
   declare
      Base : Integer;

      procedure Accumulate is
      begin
         Result := Result + Base;
      end Accumulate;
   begin
      Base := 1;
      Accumulate;
      Base := 5;
      Accumulate;
   end;
end Precision_Overwritten_Assignment_Block_Nested_Body_Clean;
