--  Uninitialized_Read: objects given a value by what names them, not by an
--  assignment: the object of T'Asm_Output (HiRTOS, rp2040_hal), one whose
--  access value or address a call is given (simple_components,
--  powerjoular, utilada), the out actual of a view conversion (sdlada), and
--  an imported object (clic).

with Interfaces;          use Interfaces;
with System;
with System.Machine_Code; use System.Machine_Code;

procedure Precision_Uninitialized_Read_Stored_Clean (Total : out Integer) is
   procedure Fill (P : access Integer)
     with Import, Convention => C, External_Name => "fill";
   procedure Fill_Address (A : System.Address)
     with Import, Convention => C, External_Name => "fill_address";
   procedure Get (V : out Long_Float) is
   begin
      V := 1.0;
   end Get;
   IPSR  : Unsigned_32;
   Count : aliased Integer;
   Size  : Integer;
   Y     : Float;
   Sep   : Character;
   pragma Import (C, Sep, "__gnat_dir_separator");
begin
   Asm ("mrs %0, ipsr", Unsigned_32'Asm_Output ("=r", IPSR), Volatile => True);
   Fill (Count'Access);
   Fill_Address (Size'Address);
   Get (Long_Float (Y));
   Total := Integer (IPSR) + Count + Size + Integer (Y) + Character'Pos (Sep);
end Precision_Uninitialized_Read_Stored_Clean;
