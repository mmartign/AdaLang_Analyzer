procedure Precision_Wrong_Parameter_Mode_Access_Profile_Clean is
   type Counter is record
      Value : Integer := 0;
   end record;

   type Routine is access procedure (Item : in out Counter);

   procedure Report (Item : in out Counter) is
   begin
      if Item.Value > 0 then
         raise Program_Error;
      end if;
   end Report;

   procedure Run (Action : Routine; Item : in out Counter) is
   begin
      Action (Item);
   end Run;

   State : Counter;
begin
   Run (Report'Access, State);
end Precision_Wrong_Parameter_Mode_Access_Profile_Clean;
