--  Resource leak checks (see the body): owning access values moved,
--  nulled, freed or given back before they are overwritten, given as an
--  out actual, or go out of scope.
package Verification_Resource_Leaks with SPARK_Mode is

   type Bytes is array (Positive range <>) of Integer;
   type Bytes_Ptr is access Bytes;

   procedure Free (P : in out Bytes_Ptr) with Post => P = null;

   --  As a RecordFlux context: one owning component, null by default.
   type Context is record
      Buffer : Bytes_Ptr;
      Last   : Natural := 0;
   end record;

   function Has_Buffer (C : Context) return Boolean is (C.Buffer /= null);

   procedure Initialize (Ctx : out Context; Buffer : in out Bytes_Ptr)
     with Pre  => Buffer /= null,
          Post => Has_Buffer (Ctx) and Buffer = null;
   procedure Take_Buffer (Ctx : in out Context; Buffer : out Bytes_Ptr)
     with Pre  => Has_Buffer (Ctx),
          Post => not Has_Buffer (Ctx) and Buffer /= null;
   procedure Give_Back (Ctx : in out Context; Buffer : in out Bytes_Ptr)
     with Pre  => not Has_Buffer (Ctx) and Buffer /= null,
          Post => Has_Buffer (Ctx) and Buffer = null;
   procedure Bump (Ctx : in out Context)
     with Pre => Has_Buffer (Ctx), Post => Has_Buffer (Ctx);
   procedure Reset_Named (Ctx : in out Context)
     with Pre => Has_Buffer (Ctx), Post => Has_Buffer (Ctx);
   procedure Reset_Update (Ctx : in out Context)
     with Pre => Has_Buffer (Ctx), Post => Has_Buffer (Ctx);
   procedure Reset_Positional (Ctx : in out Context)
     with Pre => Has_Buffer (Ctx), Post => Has_Buffer (Ctx);
   procedure Switch (Ctx : in out Context; Elem : out Context)
     with Pre  => Has_Buffer (Ctx),
          Post => not Has_Buffer (Ctx) and Has_Buffer (Elem);
   procedure Switch_Data (Pdu : in out Context; Sdu : out Context)
     with Pre  => Has_Buffer (Pdu),
          Post => not Has_Buffer (Pdu) and Has_Buffer (Sdu);
   procedure Update (Ctx : in out Context; Elem : in out Context)
     with Pre  => not Has_Buffer (Ctx) and Has_Buffer (Elem),
          Post => Has_Buffer (Ctx) and not Has_Buffer (Elem);

   --  As a RecordFlux state machine: a context moved to a _Tmp and back.
   type Outer is record
      Inner : Context;
      State : Natural := 0;
   end record;
   procedure Step (O : in out Outer; Fail : Boolean)
     with Pre => Has_Buffer (O.Inner), Post => Has_Buffer (O.Inner);

   --  As its Initialize and Finalize over allocator slots.
   type Slots is record
      S1 : Bytes_Ptr;
      S2 : Bytes_Ptr;
   end record;
   type Machine is record
      Slot : Slots;
      A, B : Context;
   end record;
   function Uninitialized (M : Machine) return Boolean is
     (not Has_Buffer (M.A) and not Has_Buffer (M.B)
      and M.Slot.S1 = null and M.Slot.S2 = null);
   function Initialized (M : Machine) return Boolean is
     (Has_Buffer (M.A) and Has_Buffer (M.B)
      and M.Slot.S1 = null and M.Slot.S2 = null);
   procedure Alloc (S : out Slots) with Post => S.S1 /= null and S.S2 /= null;
   procedure Free_Slots (S : in out Slots)
     with Post => S.S1 = null and S.S2 = null;
   procedure Start (M : in out Machine)
     with Pre => Uninitialized (M), Post => Initialized (M);
   procedure Stop (M : in out Machine)
     with Pre => Initialized (M), Post => Uninitialized (M);

   --  As the CoAP encoding: a local context and an allocated buffer.
   procedure Encode (N : Positive) with Pre => N <= 64;
   --  Moved on one path, freed on the other.
   procedure Join (Ctx : in out Context; C : Boolean)
     with Pre => not Has_Buffer (Ctx);
   --  Freed by an instance of Ada.Unchecked_Deallocation itself.
   procedure Free_Direct;

end Verification_Resource_Leaks;
