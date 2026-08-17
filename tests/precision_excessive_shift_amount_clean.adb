with Interfaces; use Interfaces;
procedure Precision_Excessive_Shift_Amount_Clean is
   X : Unsigned_8 := 1;
   Y : Unsigned_8;
begin
   Y := Shift_Left (X, 7);
end Precision_Excessive_Shift_Amount_Clean;
