with Interfaces; use Interfaces;
procedure Precision_Known_Negative_Shift_Amount_Failure_Dynamic_Clean
  (Amount : Natural)
is
   X : Unsigned_8 := 1;
   Y : Unsigned_8;
begin
   Y := Shift_Left (X, Amount);
end Precision_Known_Negative_Shift_Amount_Failure_Dynamic_Clean;
