procedure Uninitialized_Output_Overload_Defaulted_Trailing_Guard is

   --  Same resolution-fragile, defaulted-trailing-formal overload shape as
   --  the clean sibling, but the narrower overload has a second out
   --  parameter ("Unused") that the forwarding call never mentions at
   --  all. The relaxed arity gate (accepting the primary resolution
   --  whenever it has enough formals for the call, not only when its
   --  formal count matches exactly) must not become so permissive that a
   --  genuinely unwritten out parameter goes unreported.
   type XDR_Octet is mod 2**8;
   subtype XDR_Index_Type is Natural;
   type XDR_Array is array (XDR_Index_Type range <>) of XDR_Octet;
   type XDR_Integer is range -2**31 .. 2**31 - 1;
   type XDR_Unsigned is mod 2**32;

   procedure Encode
     (Value    : in     XDR_Integer;
      Data     : in out XDR_Array;
      Position : in     XDR_Index_Type;
      Last     :    out XDR_Index_Type;
      Unused   :    out XDR_Index_Type;
      Extra    : in     Natural := 0)
   is
      pragma Unreferenced (Unused);
   begin
      Encode (XDR_Unsigned (Value), Data, Position, Last);
   end Encode;

   procedure Encode
     (Value    : in     XDR_Unsigned;
      Data     : in out XDR_Array;
      Position : in     XDR_Index_Type;
      Last     :    out XDR_Index_Type;
      Extra    : in     Natural := 0)
   is
      pragma Unreferenced (Value, Extra);
   begin
      Data (Position) := 0;
      Last := Position;
   end Encode;

   D : XDR_Array (0 .. 3) := (others => 0);
   L : XDR_Index_Type;
begin
   Encode (1, D, 0, L);
end Uninitialized_Output_Overload_Defaulted_Trailing_Guard;
