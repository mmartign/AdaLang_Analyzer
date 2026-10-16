--  FP-121: an aliased parameter was taken to change only by its own name.
--  It is passed by reference, and its actual is an aliased object or a part
--  of one: called as Through_Pointer (Shared.C) or Through_Call (Shared.C),
--  the write through Ptr, and the call of Set_Shared, change V without
--  naming it, and each assertion fails.
package Verification_FP121_Aliased_Parameter is

   type Holder is record
      C : aliased Integer;
   end record;
   type Holder_Access is access all Holder;

   Shared : aliased Holder := (C => 1);
   Ptr    : Holder_Access := Shared'Access;

   procedure Set_Shared with Global => (In_Out => Shared);

   procedure Through_Pointer (V : aliased in out Integer) with Pre => V = 1;
   procedure Through_Call (V : aliased in out Integer) with Pre => V = 1;

   --  A parameter of a scalar type that is not aliased is a copy, which
   --  nothing but its own name changes.
   procedure By_Copy (V : in out Integer) with Pre => V = 1;

end Verification_FP121_Aliased_Parameter;
