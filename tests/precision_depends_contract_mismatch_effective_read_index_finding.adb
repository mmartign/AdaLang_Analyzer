with System;
--  At the shape of the effective-read regression (FP-182): the register
--  read is no output, though a read of it changes the state. Must fire.
procedure Precision_Depends_Contract_Mismatch_Effective_Read_Index_Finding
  with SPARK_Mode
is
   type Index_T is range 0 .. 15;
   type Word is mod 2 ** 32;

   package Registers
     with Abstract_State => (Register_State with External)
   is
      procedure Read (Register : Index_T; Value : out Word)
        with Global => (In_Out => Register_State),
             Depends => (Value => (Register, Register_State),
                          Register_State => Register_State);
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
end Precision_Depends_Contract_Mismatch_Effective_Read_Index_Finding;
