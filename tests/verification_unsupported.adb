procedure Verification_Unsupported (Input : Integer) is
   Result : Integer := 0;
begin
   goto Finished;
   Result := 10 / Input;

   <<Finished>>
   pragma Assert (Result = 0);
end Verification_Unsupported;
