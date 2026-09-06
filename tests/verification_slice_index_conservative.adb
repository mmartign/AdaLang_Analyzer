--  FP-064 regression: indexing into an array *slice* (Items (1 .. Last) (1))
--  must never be proved safe against the array type's declared index
--  subtype. The slice's own bounds are 1 .. Last, which is an empty range
--  when Last = 0, so index 1 is then out of bounds -- GNATprove reports
--  "array index check might fail" here. --verify must stay conservative
--  (unproved), not report proved-safe. Found via benchmarks/spark_testsuite/
--  (AdaCore SPARK testsuite unit OB26-006__ctex_array_ret_func).
procedure Verification_Slice_Index_Conservative
  (Last : Natural;
   V    : out Integer)
  with SPARK_Mode
is
   type Int_Array is array (Positive range <>) of Integer;
   Items : constant Int_Array (1 .. 10) := (others => 1);
begin
   V := Items (1 .. Last) (1);
end Verification_Slice_Index_Conservative;
