procedure Uninitialized_Read_Function_Out_Actual_Clean is

   --  An ordinary Ada function with an out-mode formal, called for its
   --  return value inside a larger expression (here, an assignment's RHS)
   --  rather than as its own call statement. Data_Flow.First_Access's
   --  Ada_Assign_Stmt case only ever checked whether the tracked
   --  declaration was the assignment's own (simple) destination or
   --  mentioned by a read in the RHS -- it never gave the RHS a chance to
   --  be recognized as a write via its own nested Ada_Call_Expr case (the
   --  one that already handles a call statement's out-mode actuals),
   --  because that whole statement always returned before falling through
   --  to the generic child recursion where that case lives. Forwarding
   --  Status as an out actual of I2C_Read, called this way, must still
   --  count as writing it.
   type UInt8 is mod 256;

   function I2C_Read (Reg : UInt8; Status : out Boolean) return UInt8 is
   begin
      Status := True;
      return Reg;
   end I2C_Read;

   Status   : Boolean;
   Nb_Touch : UInt8 := 0;
begin
   Nb_Touch := I2C_Read (16#10#, Status);

   if not Status then
      return;
   end if;
end Uninitialized_Read_Function_Out_Actual_Clean;
