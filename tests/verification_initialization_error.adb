procedure Verification_Initialization_Error
  with SPARK_Mode
is
   Source : Integer;
   Target : Integer;
begin
   Target := Source;
   pragma Assert (Target = Source);
end Verification_Initialization_Error;
