procedure Uninitialized_Output_Prefixed_Clear_Guard is

   type Queue_Type is limited record
      Count : Natural := 0;
   end record;

   procedure Clear (Self : in out Queue_Type) is
   begin
      Self.Count := 0;
   end Clear;

   procedure Reset_Only_First
     (Queue : out Queue_Type; Backup : out Queue_Type) is
   begin
      Queue.Clear;

      --  Backup is never written on this path; crediting the parameterless
      --  prefixed call above must not spill over to an unrelated out
      --  parameter.
      null;
   end Reset_Only_First;

begin
   null;
end Uninitialized_Output_Prefixed_Clear_Guard;
