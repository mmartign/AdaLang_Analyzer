--  Resource leak checks that do not hold (see the body).
package Verification_Mutation_Resource_Leaks with SPARK_Mode is

   type Bytes is array (Positive range <>) of Integer;
   type Bytes_Ptr is access Bytes;

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
   procedure Keep (B : in out Bytes_Ptr) with Pre => B /= null;

   type Outer is record
      Inner : Context;
      State : Natural := 0;
   end record;

   type Slots is record
      S1 : Bytes_Ptr;
      S2 : Bytes_Ptr;
   end record;
   procedure Alloc (S : out Slots) with Post => S.S1 /= null and S.S2 /= null;

   procedure Twice (X : out Bytes_Ptr);
   procedure Lost;
   procedure Busy_Out (Ctx : in out Context) with Pre => Has_Buffer (Ctx);
   procedure Give_Blind (Into : in out Context; From : in out Bytes_Ptr)
     with Pre => From /= null;
   procedure Half_Move (Ctx : in out Context; C : Boolean)
     with Pre => not Has_Buffer (Ctx);
   procedure Overwrite (Ctx : in out Context);
   procedure Kept_Silent;
   procedure Init_Over (Ctx : in out Context; Buffer : in out Bytes_Ptr)
     with Pre => Buffer /= null;
   procedure Tmp_Lost (O : in out Outer) with Pre => Has_Buffer (O.Inner);
   procedure Slots_Over (S : in out Slots);
   procedure Half_Free (C : Boolean);
   procedure Update_Over (Ctx : in out Context; Buffer : in out Bytes_Ptr)
     with Pre => Buffer /= null;

end Verification_Mutation_Resource_Leaks;
