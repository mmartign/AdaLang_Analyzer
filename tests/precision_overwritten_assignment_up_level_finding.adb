--  FP-144 boundary: Total belongs to the enclosing procedure, but no body
--  declared there reads it, so the first value Reset gives it is
--  overwritten before any read and must be flagged.
procedure Precision_Overwritten_Assignment_Up_Level_Finding
  (Result : out Integer)
is
   Total : Integer := 0;

   procedure Reset is
   begin
      Total := 1;
      Total := 2;
   end Reset;
begin
   Reset;
   Result := Total;
end Precision_Overwritten_Assignment_Up_Level_Finding;
