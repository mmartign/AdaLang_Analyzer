procedure Verification_VC_Enum_Assignment_Error
  with SPARK_Mode
is
   type Truth_Value is (False, True, Unknown);
   Truth : Truth_Value := False;
begin
   Truth := Unknown;
   pragma Assert (Truth = True);
end Verification_VC_Enum_Assignment_Error;
