procedure Verification_VC_Unsupported_Scalar_Sort
  (Input : Duration)
  with SPARK_Mode
is
   Copy : Duration := Input;
begin
   pragma Assert (Copy = Input);
end Verification_VC_Unsupported_Scalar_Sort;
