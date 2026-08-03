procedure Uninitialized_Read_Function_Out_Actual_Guard is

   --  Same shape as the clean sibling, but "Other" is never forwarded to
   --  I2C_Read at all: a genuinely uninitialized read must still be
   --  flagged, not spuriously cleared just because a same-statement call
   --  happens to write a different out-mode formal.
   type UInt8 is mod 256;

   function I2C_Read (Reg : UInt8; Status : out Boolean) return UInt8 is
   begin
      Status := True;
      return Reg;
   end I2C_Read;

   Status   : Boolean;
   Other    : Boolean;
   Nb_Touch : UInt8 := 0;
begin
   Nb_Touch := I2C_Read (16#10#, Status);

   if not Other then
      return;
   end if;
end Uninitialized_Read_Function_Out_Actual_Guard;
