--  Uninitialized_Read: the same call in prefix notation that Libadalang
--  does not resolve, but Err is read before it, which must still be
--  reported (FP-172).

with Registers;

procedure Precision_Uninitialized_Read_Unresolved_Prefix_Call_Finding
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
   Found := Err = None;
   Temp := Device.Read (16#20#, Registers.IOCON, Err);
   Found := Found and then Temp /= 0;
end Precision_Uninitialized_Read_Unresolved_Prefix_Call_Finding;
