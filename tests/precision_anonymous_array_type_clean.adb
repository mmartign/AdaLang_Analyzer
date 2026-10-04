procedure Precision_Anonymous_Array_Type_Clean is
   type Vector is array (1 .. 4) of Integer;
   type Holder is record
      Items : Vector;
   end record;
   Table : Holder := (Items => (others => 0));
   Ref   : access Integer := null;
begin
   Table.Items (1) := 1;
   pragma Assert (Ref = null);
end Precision_Anonymous_Array_Type_Clean;
