with GNAT.OS_Lib; use GNAT.OS_Lib;

procedure Precision_Unused_With_Clause_Renaming_Finding is
   Count : constant Integer := 1;
begin
   if Count = 2 then
      raise Program_Error;
   end if;
end Precision_Unused_With_Clause_Renaming_Finding;
