procedure Precision_Array_Slice_Clean is
   S : String (1 .. 8) := "abcdefgh";
   function Pick (I : Integer) return Character is (S (I));
begin
   S (1) := Pick (2);
end Precision_Array_Slice_Clean;
