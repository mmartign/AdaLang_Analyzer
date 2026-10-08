--  The bounds of an array are those it was declared with, and a slice has
--  the bounds its range gives where it is written: a variable that has
--  changed since says nothing of the first, and its value then nothing of
--  the second. No check here is proved, the lengths differing by one.
procedure Verification_Length_Check_State is

   type Index is range 0 .. 1000;
   type Bytes is array (Index range <>) of Natural;

   --  Local keeps the Size it was declared with.
   procedure Declared_Before (Goal : in out Bytes; Count : Index)
     with Pre => Goal'First = 1 and then Count < Goal'Last
   is
      Size  : Index := Count;
      Local : constant Bytes (1 .. Size) := (others => 0);
   begin
      Size := Size + 1;
      Goal (1 .. Size) := Local;
   end Declared_Before;

   --  Limit is no longer Count.
   procedure Changed_Since (Into : in out Bytes; From : Bytes; Count : Index)
     with Pre => Into'First = 1 and then From'First = 1
                 and then Count < Into'Last and then Count < From'Last
   is
      Limit : Index := Count;
   begin
      Limit := Limit + 1;
      Into (1 .. Count) := From (1 .. Limit);
   end Changed_Since;

   --  The subtype was elaborated when Size was one less.
   procedure Subtype_Before (Sink : in out Bytes; Count : Index)
     with Pre => Sink'First = 1 and then Count < Sink'Last
   is
      Size : Index := Count;
      subtype Sized is Bytes (1 .. Size);
      Kept : constant Sized := (others => 0);
   begin
      Size := Size + 1;
      declare
         Wider : constant Bytes (1 .. Size) := Kept;
      begin
         Sink (1) := Wider (1);
      end;
   end Subtype_Before;

begin
   null;
end Verification_Length_Check_State;
