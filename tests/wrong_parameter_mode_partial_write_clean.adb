procedure Wrong_Parameter_Mode_Partial_Write_Clean is

   --  A parameter written only through a selected/indexed component (not
   --  the parameter itself) inherently depends on every part it does not
   --  touch already holding a meaningful value from before the call, so
   --  it must not be recommended for mode "out" (observed in the wild:
   --  AWS.Config.Set's single-field config setters, each writing one
   --  element of a many-element parameter array while leaving every other
   --  configuration value untouched).
   type Value_Array is array (1 .. 4) of Integer;

   type Config is record
      Values : Value_Array := [others => 0];
   end record;

   procedure Set_Value
     (State : in out Config; Index : Positive; Value : Integer) is
   begin
      State.Values (Index) := Value;
   end Set_Value;

   C : Config;
begin
   Set_Value (C, 1, 42);
end Wrong_Parameter_Mode_Partial_Write_Clean;
