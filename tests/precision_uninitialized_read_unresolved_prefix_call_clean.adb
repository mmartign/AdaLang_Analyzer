--  Uninitialized_Read: a call in prefix notation that Libadalang does not
--  resolve, here because an actual names a unit that is not there, as
--  Ada-Lisp-Embedded's "temp := i2c_ptr.read (addr,
--  BBS.embed.i2c.MCP23017.IOCON, err);" (FP-172). The prefix is the first
--  actual: Err goes to the out formal Error, not to the in formal Reg, and
--  a call that is not resolved is an access not known, not a read.

with Registers;

procedure Precision_Uninitialized_Read_Unresolved_Prefix_Call_Clean
  (Found : out Boolean)
is
   type Err_Code is (None, Nack);
   type U8 is mod 256;

   package Buses is
      type Bus is tagged null record;
      function Read
        (Self : in out Bus; Addr : U8; Reg : U8; Error : out Err_Code)
         return U8;
   end Buses;

   package body Buses is
      function Read
        (Self : in out Bus; Addr : U8; Reg : U8; Error : out Err_Code)
         return U8 is
      begin
         Error := None;
         return Addr + Reg;
      end Read;
   end Buses;

   Device : Buses.Bus;
   Err    : Err_Code;
   Temp   : U8;
begin
   Temp := Device.Read (16#20#, Registers.IOCON, Err);
   Found := Err = None and then Temp /= 0;
end Precision_Uninitialized_Read_Unresolved_Prefix_Call_Clean;
