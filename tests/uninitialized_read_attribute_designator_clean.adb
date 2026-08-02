with Ada.Strings.Fixed;

procedure Uninitialized_Read_Attribute_Designator_Clean (Data : String) is

   --  An attribute designator ("Last" in "Data'Last") is syntactically an
   --  identifier but never refers to a declaration. "Last" and "First"
   --  are also two of the most common variable names for tracking
   --  string/array bounds -- exactly the scenario this collides with
   --  (observed in the wild in AWS.Headers.Values.Next_Value): the local
   --  variable's own initializing assignment must not be mistaken for a
   --  read of itself just because the assignment's expression also
   --  mentions an unrelated object's 'Last attribute.
   Last : Natural;

begin
   Last := Ada.Strings.Fixed.Index (Data (Data'First .. Data'Last), "x");
   if Last = 0 then
      null;
   end if;
end Uninitialized_Read_Attribute_Designator_Clean;
