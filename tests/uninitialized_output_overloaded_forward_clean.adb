with Ada.Unchecked_Conversion;
procedure Uninitialized_Output_Overloaded_Forward_Clean is
   --  Several overloads share the same parameter count and modes,
   --  differing only in Value's type -- a common shape for a family of
   --  Encode/Decode procedures. Encode forwards its own out parameter
   --  Last, purely positionally, to another overload of itself. Ada's
   --  own overload resolution can determine which Encode is meant here,
   --  but Libadalang's precise per-call and per-actual resolution
   --  properties can still raise on a call this ambiguous, even with
   --  Imprecise_Fallback requested; only resolving the callee name on
   --  its own (a more lenient operation) succeeds.
   type XDR_Octet is mod 2**8;
   subtype XDR_Index_Type is Natural;
   type XDR_Array is array (XDR_Index_Type range <>) of XDR_Octet;
   type XDR_Integer is range -2**31 .. 2**31 - 1;
   type XDR_Unsigned is mod 2**32;
   type XDR_Boolean is (XDR_False, XDR_True);

   function XDR_Integer_To_Unsigned is new Ada.Unchecked_Conversion
     (Source => XDR_Integer, Target => XDR_Unsigned);

   procedure Encode
     (Value    : in     XDR_Integer;
      Data     : in out XDR_Array;
      Position : in     XDR_Index_Type;
      Last     :    out XDR_Index_Type)
   is
   begin
      Encode (XDR_Integer_To_Unsigned (Value), Data, Position, Last);
   end Encode;

   procedure Encode
     (Value    : in     XDR_Unsigned;
      Data     : in out XDR_Array;
      Position : in     XDR_Index_Type;
      Last     :    out XDR_Index_Type)
   is
      Temporary_1 : XDR_Unsigned := Value;
      Temporary_2 : XDR_Unsigned;
   begin
      for I in 1 .. 4 loop
         Temporary_2 := Temporary_1 rem 256;
         Data (Position + (4 - I)) := XDR_Octet (Temporary_2);
         Temporary_1 := Temporary_1 / 256;
      end loop;
      Last := Position + (4 - 1);
   end Encode;

   procedure Encode
     (Value    : in     XDR_Boolean;
      Data     : in out XDR_Array;
      Position : in     XDR_Index_Type;
      Last     :    out XDR_Index_Type)
   is
      Temporary : XDR_Unsigned;
   begin
      if Value = XDR_False then
         Temporary := 0;
      else
         Temporary := 1;
      end if;
      Encode (Temporary, Data, Position, Last);
   end Encode;

   D : XDR_Array (0 .. 3) := (others => 0);
   L : XDR_Index_Type;
begin
   Encode (XDR_True, D, 0, L);
end Uninitialized_Output_Overloaded_Forward_Clean;
