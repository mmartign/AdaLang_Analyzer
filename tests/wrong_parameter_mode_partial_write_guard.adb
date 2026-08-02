procedure Wrong_Parameter_Mode_Partial_Write_Guard is

   type Config is record
      Value : Integer := 0;
   end record;

   --  A direct, whole-object assignment (as opposed to a write through a
   --  selected/indexed component) genuinely establishes the parameter's
   --  entire value from scratch, so it must still be recommended for mode
   --  "out".
   procedure Reset (State : in out Config) is
   begin
      State := (Value => 0);
   end Reset;

begin
   null;
end Wrong_Parameter_Mode_Partial_Write_Guard;
