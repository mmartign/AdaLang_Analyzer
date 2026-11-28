--  An exception handler runs only for an exception the statements raise,
--  after the declarations: an out parameter set before anything that can
--  raise (scalars in range, an "others" or exact-length aggregate, a record
--  aggregate of such values) is set in the handler too (Ironclad's
--  IPC.Futex.Wake, Sound.Get_Audio_Device_Limits, Networking.DHCP.Discover,
--  FP-192).
with Interfaces; use Interfaces;
procedure Precision_Uninitialized_Output_Handler_After_Set_Clean
  (N : Natural; Count : out Natural; Done : out Boolean;
   Address : out Unsigned_32)
is
   type IPv4 is array (1 .. 4) of Unsigned_8;
   type Lease_Record is record
      IP    : IPv4;
      Time  : Unsigned_32;
      Valid : Boolean;
   end record;
   procedure Discover (Lease : out Lease_Record; Code : out Unsigned_8) is
      A : array (1 .. 4) of Natural := [others => 0];
   begin
      Lease := (IP => [0, 0, 0, 0], Time => 0, Valid => False);
      Code := 16#FF#;
      for I in 1 .. N loop
         A (I) := I;
      end loop;
      Lease.Valid := A (1) > 0;
   exception
      when Constraint_Error =>
         null;
   end Discover;
   function Get (V : out Unsigned_32) return Boolean is
   begin
      V := 1;
      return True;
   end Get;
   Got : constant Boolean := Get (Address);
   A   : array (1 .. 4) of Natural := [others => 0];
begin
   Count := 0;
   Done := False;
   for I in 1 .. N loop
      A (I) := I;
      Count := Count + 1;
   end loop;
   Done := Got;
exception
   when Constraint_Error =>
      null;
end Precision_Uninitialized_Output_Handler_After_Set_Clean;
