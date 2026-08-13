procedure Verification_VC_Enum_Assignment
  with SPARK_Mode
is
   type Role is (Guest, Member, Admin);
   type Truth_Value is (False, True, Unknown);

   procedure Check_Copy (Input : Role) is
      Copy : Role := Guest;
   begin
      Copy := Input;
      if Copy = Admin then
         pragma Assert (Input = Admin);
      end if;
   end Check_Copy;

   Current : Role := Guest;
   Truth   : Truth_Value := False;
begin
   Current := Admin;
   pragma Assert (Current = Admin);
   pragma Assert (Current in Guest | Admin);

   Truth := Unknown;
   pragma Assert (Truth /= True);

   Check_Copy (Current);
end Verification_VC_Enum_Assignment;
