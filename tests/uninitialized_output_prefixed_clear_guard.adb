procedure Uninitialized_Output_Prefixed_Clear_Guard is

   --  Neither limited nor with a default: an out parameter of such a type
   --  keeps a value, and is not reported outside SPARK (FP-149).
   type Queue_Type is record
      Count : Natural;
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
