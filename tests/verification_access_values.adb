package body Verification_Access_Values is

   The_Cell : aliased Cell;

   overriding procedure Initialize (Object : in out Counted) is
   begin
      Counter := Counter + 1;
   end Initialize;

   function Get return not null access Cell is
   begin
      return The_Cell'Access;
   end Get;

   function Bump_Get return Integer is
   begin
      Counter := Counter + 1;
      return Counter;
   end Bump_Get;

   procedure Global_Through_Address is
      P    : constant Conv.Object_Pointer := Conv.To_Pointer (Global'Address);
      Was  : Integer;
   begin
      Global := 1;
      P.all := 2;
      Was := Global;
      pragma Assert (Was = 1);
   end Global_Through_Address;

   procedure Local_Through_Address is
      Own : Integer;
      P   : Conv.Object_Pointer;
   begin
      Own := 1;
      P := Conv.To_Pointer (Own'Address);
      P.all := 2;
      pragma Assert (Own = 1);
   end Local_Through_Address;

   procedure Call_Through_Pointer (Callback : not null access procedure) is
   begin
      Counter := 0;
      Callback.all;
      pragma Assert (Counter = 0);
   end Call_Through_Pointer;

   procedure Function_Through_Pointer is
      Got : Integer;
   begin
      Counter := 0;
      Got := FA.all;
      pragma Assert (Counter + 0 = 0);
   end Function_Through_Pointer;

   procedure Controlled_Allocator is
      Made : Counted_Access;
   begin
      Counter := 0;
      Made := new Counted;
      pragma Assert (Counter - 0 = 0);
   end Controlled_Allocator;

   procedure Allocator_Default is
      Made : Int_Access;
   begin
      Counter := 0;
      Made := new Integer'(Bump_Get);
      pragma Assert (0 = Counter);
   end Allocator_Default;

   procedure Pointer_Actual is
      procedure Set (V : out Integer) is
      begin
         V := 2;
      end Set;
   begin
      Global := 1;
      Set (Conv.To_Pointer (Global'Address).all);
      pragma Assert (Global = 1);
   end Pointer_Actual;

   --  A subprogram that takes no address keeps its own objects: a write
   --  through an access value cannot reach them.
   procedure Locals_Stand (Q : Int_Access) is
      Mine : Integer;
      Got  : Integer;
   begin
      Mine := 1;
      Got := Q.all;
      Q.all := Got;
      pragma Assert (Mine = 1);
   end Locals_Stand;

   procedure Copy_Stands (V : in out Integer) is
   begin
      GI.all := 2;
      pragma Assert (V = 1);
   end Copy_Stands;

   --  Nothing changes the cell between the two reads.
   procedure Read_Twice is
      C     : constant not null access Cell := Get;
      First : constant Integer := C.Last;
      Next  : Integer;
   begin
      Next := First + 1;
      pragma Assert (C.Last = First);
   end Read_Twice;

end Verification_Access_Values;
