with Interfaces; use Interfaces;
procedure Precision_Known_Negative_Shift_Amount_Failure_Clean is
   X : Unsigned_8 := 1;
   Y : Unsigned_8;
begin
   Y := Shift_Left (X, 0);
end Precision_Known_Negative_Shift_Amount_Failure_Clean;
