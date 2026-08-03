procedure Uninitialized_Read_Named_Actual_Designator_Guard is

   --  Same colliding-name shape as the clean sibling, but this time "LSB"
   --  genuinely is passed as the actual expression (not just sharing its
   --  spelling with the designator) before ever being assigned: a real
   --  read-before-assignment, which must still be flagged.
   type UInt8 is mod 256;
   type Integer_16 is range -32768 .. 32767;

   function To_Integer_16 (LSB, MSB : UInt8) return Integer_16 is
   begin
      return Integer_16 (LSB) + Integer_16 (MSB);
   end To_Integer_16;

   LSB   : UInt8;
   New_X : Integer_16;
begin
   New_X := To_Integer_16 (LSB => LSB, MSB => 2);
end Uninitialized_Read_Named_Actual_Designator_Guard;
