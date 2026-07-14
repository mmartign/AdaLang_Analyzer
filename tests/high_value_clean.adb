--  Negative fixture for the new high-value checks: it uses named constants,
--  exempt numeric values, and a tolerance-based floating-point comparison.
procedure High_Value_Clean is
   Named_Two : constant := 2;
   Left      : Float := 0.0;
   Right     : Float := 1.0;
   Value     : Integer := -1;
begin
   if abs (Left - Right) < Float'Model_Epsilon then
      Value := Named_Two;
   end if;
end High_Value_Clean;
