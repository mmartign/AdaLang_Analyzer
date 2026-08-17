with Interfaces; use Interfaces;
procedure Precision_Excessive_Shift_Amount_Finding is
   X : Unsigned_8 := 1;
   Y : Unsigned_8;
begin
   Y := Shift_Left (X, 8);
end Precision_Excessive_Shift_Amount_Finding;
