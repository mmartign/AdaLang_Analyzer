procedure Verification_Diff_Runtime_Relational
  (X, Y : Integer;
   Data : String;
   Sink : out Character)
with
  SPARK_Mode,
  Pre => X >= 0
    and then X <= Y
    and then Y <= 10
    and then Data'First = 1
    and then Data'Last >= 11
is
   subtype Difference is Integer range -10 .. 0;
   D : Difference;
begin
   D := X - Y;
   Sink := Data (X - Y + 11);

   if X < Y then
      D := 1 / (Y - X) - 1;
   end if;
end Verification_Diff_Runtime_Relational;
