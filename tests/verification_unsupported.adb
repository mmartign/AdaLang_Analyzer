procedure Verification_Unsupported (Input : Integer) is
   Result : Integer := 0;
begin
   <<Again>>
   Result := Result + 1;
   if Result < Input then
      goto Again;
   end if;

   pragma Assert (Result > 0);
end Verification_Unsupported;
