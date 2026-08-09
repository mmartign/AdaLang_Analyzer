procedure Uninitialized_Output_Overload_Defaulted_Trailing_Clean is

   --  Two same-named overloads sharing the same parameter count and modes
   --  (forcing Libadalang's own precise per-call resolution, P_Get_Params,
   --  to fail even with Imprecise_Fallback set -- the same trigger already
   --  documented for the sibling Overloaded_Forward fixture), where the
   --  callee also carries a trailing defaulted formal ("Extra") omitted
   --  from the forwarding call. Callee_Formal_At_Position's own arity
   --  gate against a wrong-overload resolution (FP-044) must reject the
   --  primary resolution only when the call has MORE actuals than the
   --  resolved candidate can accept, not merely when the counts differ:
   --  a correctly-resolved callee legally has more formals than actuals
   --  when trailing ones default, and requiring exact equality here
   --  wrongly discarded this call's own correct primary resolution,
   --  observed live on GNATCOLL's own Full_Parse calls (Str, Msg,
   --  Store_Headers => ..., with a trailing defaulted formal omitted).
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
      Extra    : in     Natural := 0)
   is
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
end Uninitialized_Output_Overload_Defaulted_Trailing_Clean;
