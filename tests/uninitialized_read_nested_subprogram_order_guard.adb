procedure Uninitialized_Read_Nested_Subprogram_Order_Guard is

   --  Skipping over a nested subprogram body while scanning for the first
   --  access must not also skip a genuine, direct read in the enclosing
   --  subprogram's own statements: A is read here before ever being
   --  assigned, and Helper's unrelated declaration must not hide that.
   function Outer return Integer is
      A : Integer;

      function Helper return Integer is
      begin
         return 42;
      end Helper;

   begin
      return A + Helper;
   end Outer;

   Result : Integer;
begin
   Result := Outer;
end Uninitialized_Read_Nested_Subprogram_Order_Guard;
