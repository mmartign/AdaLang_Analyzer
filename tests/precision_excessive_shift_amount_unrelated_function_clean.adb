procedure Precision_Excessive_Shift_Amount_Unrelated_Function_Clean is
   function Shift_Left (X : Integer; N : Integer) return Integer is (X);
   Y : Integer;
begin
   Y := Shift_Left (5, 40);
end Precision_Excessive_Shift_Amount_Unrelated_Function_Clean;
