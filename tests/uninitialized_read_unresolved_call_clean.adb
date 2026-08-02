procedure Uninitialized_Read_Unresolved_Call_Clean is
   Value : Boolean;
begin
   --  An unavailable callee may initialize Value. Without a resolved formal
   --  mode, a later read is unknown rather than definitely before any write.
   External_Initialize (Value);
   if Value then
      null;
   end if;
end Uninitialized_Read_Unresolved_Call_Clean;
