package body Own_State.User
  with SPARK_Mode
is
   --  Depends on Timer.Abstract_Time through Raw_Value_Max, as it says.
   procedure Sample (Value : out T) is
   begin
      Value := Own_State.Timer.Raw_Value_Max;
   end Sample;
end Own_State.User;
