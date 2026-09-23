with GNAT.OS_Lib; use GNAT.OS_Lib;

procedure Precision_Unused_With_Clause_Renaming_Clean is
   Descriptor : constant File_Descriptor := Standout;
begin
   if Descriptor = Invalid_FD then
      OS_Exit (1);
   end if;
end Precision_Unused_With_Clause_Renaming_Clean;
