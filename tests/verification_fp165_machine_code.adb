--  FP-165: machine code reads and changes what no Ada object stands for,
--  the registers and the state of the processor. A function whose value
--  comes from machine code ("mrs" of the CPSR, HiRTOS's
--  Cpu_In_Privileged_Mode) is a function of its arguments only as SPARK
--  takes it, and an "svc" can change it: "Pre => not Privileged, Post =>
--  Privileged" around an Asm statement is not violated on every exit, so
--  it is unproved, not a definite error.

with System.Machine_Code;

procedure Verification_FP165_Machine_Code with SPARK_Mode => On is
   type Register is mod 2**32;

   function Status return Register is
      Value : Register;
   begin
      System.Machine_Code.Asm
        ("mrs %0, cpsr",
         Outputs  => Register'Asm_Output ("=r", Value),
         Volatile => True);
      return Value;
   end Status;

   function Privileged return Boolean is
      Value : constant Register := Status;
   begin
      return (Value and 16#1F#) /= 16#10#;
   end Privileged;

   procedure To_Privileged with
     Pre  => not Privileged,
     Post => Privileged;

   procedure To_Privileged is
   begin
      System.Machine_Code.Asm ("svc #0", Volatile => True);
   end To_Privileged;
begin
   if not Privileged then
      To_Privileged;
   end if;
end Verification_FP165_Machine_Code;
