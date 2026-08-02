with Ada.Calendar;
procedure Uninitialized_Output_Named_Actual_Forward_Guard is

   protected Store is
      procedure Update
        (Stamp : Ada.Calendar.Time; Result : out Natural);
   private
      Value : Natural := 0;
   end Store;

   protected body Store is
      procedure Update
        (Stamp : Ada.Calendar.Time; Result : out Natural) is
      begin
         Value  := Value + 1;
         Result := Value;
      end Update;
   end Store;

   procedure Forward_Missing_Result
     (Stamp : Ada.Calendar.Time; Result : out Natural) is
   begin
      --  Only "Stamp" (an "in" formal) is meaningful here; "Result" (the
      --  genuinely "out" formal) is never forwarded or otherwise written,
      --  so this must still be flagged, even though Store.Update itself
      --  hits the same P_Get_Params resolution gap as the clean sibling.
      null;
   end Forward_Missing_Result;

begin
   null;
end Uninitialized_Output_Named_Actual_Forward_Guard;
