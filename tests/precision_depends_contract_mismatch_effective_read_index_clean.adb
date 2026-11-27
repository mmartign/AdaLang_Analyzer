with System;
--  Precision regression for Depends_Contract_Mismatch (FP-182, libgfxinit's
--  Registers.Read): reading an element of a volatile object, whose reads
--  have effects, changes the object as the index says, so the state
--  depends on the index. Must not fire.
procedure Precision_Depends_Contract_Mismatch_Effective_Read_Index_Clean
  with SPARK_Mode
is
   type Index_T is range 0 .. 15;
   type Word is mod 2 ** 32;

   package Registers
     with Abstract_State => (Register_State with External)
   is
      procedure Read (Register : Index_T; Value : out Word)
        with Global => (In_Out => Register_State),
             Depends => ((Value, Register_State) =>
                           (Register, Register_State));
   end Registers;

   package body Registers
     with Refined_State => (Register_State => MMIO)
   is
      type Regs_T is array (Index_T) of Word;
      MMIO : Regs_T with Volatile, Import, Address => System'To_Address (16#1000#);

      procedure Read (Register : Index_T; Value : out Word)
        with Refined_Global => (In_Out => MMIO)
      is
      begin
         Value := MMIO (Register);
      end Read;
   end Registers;

   X : Word;
begin
   Registers.Read (3, X);
end Precision_Depends_Contract_Mismatch_Effective_Read_Index_Clean;
