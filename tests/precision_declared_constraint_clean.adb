--  The values fit the constraint the declaration of each target adds to
--  its type (FP-107): nothing to flag.
procedure Precision_Declared_Constraint_Clean (Result : out Integer) is
   type Vector is array (1 .. 4) of Integer range 0 .. 9;
   type Holder is record
      Level : Integer range 1 .. 5 := 1;
   end record;

   Limit : constant Integer := 4;
   Held  : Integer range 1 .. Limit := 1;
   Data  : Vector := (others => 0);
   Item  : Holder;
begin
   Held := 4;
   Data (1) := 9;
   Item.Level := 5;
   Result := Held + Data (1) + Item.Level;
end Precision_Declared_Constraint_Clean;
