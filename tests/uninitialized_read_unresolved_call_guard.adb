procedure Uninitialized_Read_Unresolved_Call_Guard is
   procedure Consume (Item : Boolean) is
      pragma Unreferenced (Item);
   begin
      null;
   end Consume;

   Value : Boolean;
begin
   --  A resolved input formal still consumes the incoming value and must be
   --  reported as a read before initialization.
   Consume (Value);
end Uninitialized_Read_Unresolved_Call_Guard;
