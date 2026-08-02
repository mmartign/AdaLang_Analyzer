procedure Verification_Initialization_Rename_Error is
   Source : Integer;
   Alias  : Integer renames Source;
   Target : Integer;
begin
   Target := Alias;
   pragma Assert (Target = Alias);
end Verification_Initialization_Rename_Error;
