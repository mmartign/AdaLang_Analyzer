--  At the shape of the instance-state regression (FP-182): the Depends
--  aspect has the copy run the wrong way, from GTT_State to
--  Register_State. Must fire.
procedure Precision_Depends_Contract_Mismatch_Instance_State_Finding
  with SPARK_Mode
is
   type Word is mod 2 ** 32;

   generic
   package Ranges with Abstract_State => State, Initializes => State is
      procedure Read (Value : out Word)
        with Global => (Input => State), Depends => (Value => State);
      procedure Write (Value : Word)
        with Global => (Output => State), Depends => (State => Value);
   end Ranges;

   package body Ranges with Refined_State => (State => Cell) is
      Cell : Word := 0;
      procedure Read (Value : out Word) with Refined_Global => (Input => Cell) is
      begin
         Value := Cell;
      end Read;
      procedure Write (Value : Word) with Refined_Global => (Output => Cell) is
      begin
         Cell := Value;
      end Write;
   end Ranges;

   package Registers
     with Abstract_State => (Register_State, GTT_State),
          Initializes => (Register_State, GTT_State)
   is
      procedure Copy
        with Global => (Input => Register_State, In_Out => GTT_State),
             Depends => (GTT_State => GTT_State, null => Register_State);
   end Registers;

   package body Registers
     with Refined_State => (Register_State => Regs.State,
                            GTT_State      => GTT.State)
   is
      package Regs is new Ranges;
      package GTT is new Ranges;

      procedure Copy is
         V : Word;
      begin
         Regs.Read (V);
         GTT.Write (V);
      end Copy;
   end Registers;
begin
   Registers.Copy;
end Precision_Depends_Contract_Mismatch_Instance_State_Finding;
