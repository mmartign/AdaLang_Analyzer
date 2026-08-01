procedure Uninitialized_Output_Nested_Call_Clean (Value : out Integer) is

   procedure Set_Value
     with Global => (Output => Value)
   is
   begin
      Value := 0;
   end Set_Value;

begin
   --  Value is written unconditionally, but only through a nested
   --  procedure whose own Global contract declares it writes the
   --  enclosing out parameter as an up-level global -- Value is never
   --  passed as an actual argument at this call site, so a scan limited
   --  to actual parameters would never see the write.
   Set_Value;
end Uninitialized_Output_Nested_Call_Clean;
