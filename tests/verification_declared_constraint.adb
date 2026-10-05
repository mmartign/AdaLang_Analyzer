--  The subtype an assigned value must belong to is the one the declaration
--  of the target gives it, constraint included: that of the object, of the
--  record component, of the array's components, or of the object a renaming
--  renames (FP-107). Each value below fits.
procedure Verification_Declared_Constraint
  with SPARK_Mode
is
   subtype Small is Integer range 1 .. 10;
   type Rec is record
      Level : Integer range 1 .. 5 := 1;
   end record;
   type Vec is array (1 .. 4) of Integer range 0 .. 9;

   procedure Into_Object (Fits : Integer; Result : out Integer)
     with Pre => Fits in 1 .. 5
   is
      Held : Integer range 1 .. 5 := Fits;
   begin
      Held := Fits;
      Result := Held;
   end Into_Object;

   procedure Into_Narrowed (Within : Small; Result : out Integer)
     with Pre => Within in 2 .. 3
   is
      Kept : Small range 2 .. 3 := 2;
   begin
      Kept := Within;
      Result := Kept;
   end Into_Narrowed;

   procedure Into_Component (Grade : Integer; Item : in out Rec)
     with Pre => Grade in 1 .. 5
   is
   begin
      Item.Level := Grade;
   end Into_Component;

   procedure Into_Element (Digit : Integer; Data : in out Vec)
     with Pre => Digit in 0 .. 9
   is
   begin
      Data (2) := Digit;
   end Into_Element;

   procedure Through_Renaming (Low : Integer; Result : out Integer)
     with Pre => Low in 1 .. 5
   is
      Store : Integer range 1 .. 5 := 1;
      Alias : Integer renames Store;
   begin
      Alias := Low;
      Result := Store;
   end Through_Renaming;

   Item    : Rec;
   Data    : Vec := (others => 0);
   Outcome : Integer;
begin
   Into_Object (3, Outcome);
   Into_Narrowed (2, Outcome);
   Into_Component (4, Item);
   Into_Element (7, Data);
   Through_Renaming (5, Outcome);
end Verification_Declared_Constraint;
