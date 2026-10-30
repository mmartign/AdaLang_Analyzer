--  FP-134: an object declared with another name in one declaration kept
--  what was known of it across a call that writes it, so a read after the
--  call was decided on the value from before. Neither division below is
--  safe: the first has 5 for its operand and the second can have.
package Verification_FP134_Several_Names
  with SPARK_Mode
is
   First, Second : Integer := 0;
   Alone         : Integer := 0;

   procedure Store_First (N : Integer) with Global => (Output => First);
   procedure Store_Second (N : Integer) with Global => (Output => Second);
   procedure Store_Alone (N : Integer) with Global => (Output => Alone);

   procedure Use_First (R : out Integer)
     with Global => (In_Out => First);
   procedure Use_Second (R : out Integer)
     with Global => (In_Out => Second);
   procedure Use_Alone (R : out Integer)
     with Global => (In_Out => Alone);
end Verification_FP134_Several_Names;
