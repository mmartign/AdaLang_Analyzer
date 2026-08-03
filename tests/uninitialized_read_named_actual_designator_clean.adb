procedure Uninitialized_Read_Named_Actual_Designator_Clean is

   --  A named-actual designator ("LSB" in "To_Integer_16 (LSB => ...)")
   --  names the *callee's* formal, never a reference to any declaration
   --  visible at the call site -- the same shape as the attribute-
   --  designator collision already fixed for Uninitialized_Read
   --  (FP-015), and reached the same way: Reads_Declaration's generic
   --  fallback over an unhandled node (here, a Param_Assoc whose F_R_Expr
   --  is not itself a plain identifier) walks every child indiscriminately,
   --  including F_Designator alongside F_R_Expr. An unrelated local "LSB"
   --  that happens to share its spelling with the formal, and is not
   --  otherwise assigned before this call, must not be misclassified as
   --  read by it.
   type UInt8 is mod 256;
   type Integer_16 is range -32768 .. 32767;

   function To_Integer_16 (LSB, MSB : UInt8) return Integer_16 is
   begin
      return Integer_16 (LSB) + Integer_16 (MSB);
   end To_Integer_16;

   LSB   : Float;
   New_X : Integer_16;
begin
   New_X := To_Integer_16 (LSB => 1, MSB => 2);
   LSB := 0.0;
end Uninitialized_Read_Named_Actual_Designator_Clean;
