pragma SPARK_Mode (On);

package body Verification_Standing_Values is

   Anchor : aliased constant Positive := 4;

   package body Sized is

      Mark : Index := 0;

      --  A constant is within its subtype, whatever it was given.
      function By_Constant (Value : Natural) return Natural is
      begin
         return Value / Bits;
      end By_Constant;

      --  A formal object of mode "in" is a constant of the instance.
      function By_Formal (Value : Natural) return Natural is
      begin
         return Value / Width;
      end By_Formal;

      --  A constant declared from one of them is checked against its own
      --  subtype, and is within it afterwards.
      function By_Local_Constant (Value : Natural) return Natural is
         Step : constant Positive := Bits;
      begin
         return Value / Step;
      end By_Local_Constant;

      --  Within its subtype is not away from zero.
      function By_Natural_Constant (Value : Natural) return Natural is
      begin
         return Value / Spare;
      end By_Natural_Constant;

      function By_Natural_Formal (Value : Natural) return Natural is
      begin
         return Value / Count;
      end By_Natural_Formal;

      --  A variable is not a constant: nothing here says it holds a value.
      function By_Variable (Value : Natural) return Natural is
      begin
         return Value / Shared;
      end By_Variable;

      --  Nor is a formal object of mode "in out", which names a variable.
      function By_Variable_Formal (Value : Natural) return Natural is
      begin
         return Value / Level;
      end By_Variable_Formal;

      --  A call whose effects are not known changes no "in" parameter of
      --  its caller.
      procedure After_Notify (Items : in out Vec; Chosen : Index) is
      begin
         Notify;
         Items (Chosen) := 0;
      end After_Notify;

      --  It may change a variable.
      procedure Marked (Items : in out Vec) is
      begin
         Mark := 5;
         Notify;
         pragma Assert (Mark = 5);
         Items (0) := 0;
      end Marked;

      --  What one round found of its constant says nothing of the
      --  constant of the next round, whatever was called in between.
      procedure Lapped (Items : in out Vec) is
      begin
         for Lap in Index loop
            declare
               Held : constant Index := Lap;
            begin
               Notify;
               pragma Assert (Held <= 5);
               if Held > 5 then
                  return;
               end if;
               Items (Held) := 1;
            end;
         end loop;
      end Lapped;

      --  Nor of the parameter of the loop, which is still within its
      --  range.
      procedure Turned (Items : in out Vec) is
      begin
         for Turn in Index loop
            Notify;
            pragma Assert (Turn <= 6);
            exit when Turn > 6;
            Items (Turn) := 1;
         end loop;
      end Turned;

   end Sized;

   Knob : Positive := 3;

   procedure Ring is null;

   package Narrow is new Sized
     (Width => 8, Count => 0, Level => Knob, Notify => Ring);

   --  The value of a deferred constant is in the private part.
   function By_Deferred (Value : Natural) return Natural is
   begin
      return Value / Ceiling;
   end By_Deferred;

   --  An aliased constant can be reached through an access value.
   function By_Aliased (Value : Natural) return Natural is
   begin
      return Value / Anchor;
   end By_Aliased;

   function Total (Items : Vec) return Wide is
   begin
      return Items (0) + Items (1);
   end Total;

   --  A loop over "T range L .. H" stays within T, and within what L and
   --  H can be; so does the parameter of a quantified expression.
   procedure Clear_Up_To (Items : in out Vec; Last : Index) is
   begin
      for Slot in Index range 0 .. Last loop
         Items (Slot) := 0;
         pragma Loop_Invariant
           (for all Done in Index range 0 .. Slot => Items (Done) = 0);
      end loop;
   end Clear_Up_To;

   procedure Set_From (Items : in out Vec; First : Index) is
   begin
      for Place in First .. Index'Last loop
         Items (Place) := 1;
         pragma Loop_Invariant
           (for all Tail in First .. Place => Items (Tail) = 1);
      end loop;
   end Set_From;

   --  One past the parameter is one past its range.
   procedure Shifted (Items : in out Vec; Last : Index) is
   begin
      for Spot in Index range 0 .. Last loop
         Items (Spot) := 0;
         pragma Loop_Invariant
           (for all Next in Index range 0 .. Spot => Items (Next + 1) >= 0);
      end loop;
   end Shifted;

   --  A parameter of a wider type is within that type, not within the
   --  index type.
   procedure Beyond (Items : in out Vec; Bound : Long_Index) is
   begin
      for Step in Long_Index range 0 .. Bound loop
         Items (Index (Step)) := 0;
         pragma Loop_Invariant
           (for all Far in Long_Index range 0 .. Step =>
              Items (Index (Far)) = 0);
      end loop;
   end Beyond;

   --  A constant of a block is declared again each time round: it holds
   --  a value, not the one it held before.
   procedure Each_Round (Items : in out Vec) is
   begin
      for Round in Index loop
         declare
            Seen : constant Index := Round;
         begin
            pragma Assert (Seen = 0);
            Items (Seen) := 0;
         end;
      end loop;
   end Each_Round;

   --  A named number is its value in a product too.
   function Scaled (Left, Right : Limb) return Wide is
   begin
      return Scale * (Left + Right);
   end Scaled;

   function Overscaled (Left, Right : Limb) return Wide is
      Both : constant Wide := Left + Right;
   begin
      return Huge * Both;
   end Overscaled;

   procedure Reserve (Room, Used, Extra : Natural; Sum : out Natural) is
   begin
      Sum := Used + Extra;
   end Reserve;

end Verification_Standing_Values;
