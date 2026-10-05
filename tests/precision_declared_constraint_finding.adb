--  FP-107 counterpart: the value fits Integer but not the constraint the
--  declaration of the target adds to it, so each assignment must be flagged.
procedure Precision_Declared_Constraint_Finding (Result : out Integer) is
   type Vector is array (1 .. 4) of Integer range 0 .. 9;
   type Holder is record
      Level : Integer range 1 .. 5 := 1;
   end record;

   Limit : constant Integer := 4;
   Held  : Integer range 1 .. Limit := 1;
   Data  : Vector := (others => 0);
   Item  : Holder;
begin
   Held := 5;
   Data (1) := 10;
   Item.Level := 0;
   Result := Held + Data (1) + Item.Level;
end Precision_Declared_Constraint_Finding;
