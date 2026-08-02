procedure Dead_Store_Renaming_Of_Parameter_Field_Guard is
   type Details is (None, Some_Error);
   type State is record
      Error_Detail : Details := None;
   end record;

   --  Excluding a renaming of part of a longer-lived object (a
   --  parameter's or global's field) must not also exclude a renaming of
   --  a genuinely local object: "Info" here aliases "Local", itself local
   --  to Process, so a write through it that is never read again is still
   --  a real dead store.
   procedure Process is
      Local : State;
      Info  : Details renames Local.Error_Detail;
   begin
      Info := Some_Error;
   end Process;
begin
   Process;
end Dead_Store_Renaming_Of_Parameter_Field_Guard;
