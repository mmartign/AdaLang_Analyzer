--  Dereferences, allocators and anonymous access types inside the verified
--  subset. What an access value designates is never worked out: a write
--  through "P.all" may change any object declared outside the subprogram,
--  and any of its own when it takes the address of one; an allocator and a
--  call through an access value run code that is not known. Each assertion
--  of Global_Through_Address, Local_Through_Address, Call_Through_Pointer,
--  Function_Through_Pointer, Controlled_Allocator, Allocator_Default and
--  Pointer_Actual fails at run time (FA designating Bump_Get, the callback
--  incrementing Counter). The others hold.
with Ada.Finalization;
with System.Address_To_Access_Conversions;

package Verification_Access_Values is

   type Int_Access is access all Integer;
   type Func_Access is access function return Integer;

   Global  : Integer := 0;
   Counter : Integer := 0;
   GI      : Int_Access;
   FA      : Func_Access;

   type Counted is new Ada.Finalization.Controlled with null record;
   overriding procedure Initialize (Object : in out Counted);
   type Counted_Access is access Counted;

   type Cell is record
      Last : Integer := 0;
   end record;
   function Get return not null access Cell;

   package Conv is new System.Address_To_Access_Conversions (Integer);

   function Bump_Get return Integer;

   procedure Global_Through_Address;
   procedure Local_Through_Address;
   procedure Call_Through_Pointer (Callback : not null access procedure);
   procedure Function_Through_Pointer;
   procedure Controlled_Allocator;
   procedure Allocator_Default;
   procedure Pointer_Actual;

   procedure Locals_Stand (Q : Int_Access);
   procedure Copy_Stands (V : in out Integer) with Pre => V = 1;
   procedure Read_Twice;

end Verification_Access_Values;
