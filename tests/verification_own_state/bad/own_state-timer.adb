package body Own_State.Timer
  with SPARK_Mode,
       Refined_State => (Timer_State => null, Abstract_Time => null)
is
   function Clock return T
   with Import, Convention => C, External_Name => "clock",
        Volatile_Function, Global => (Input => Abstract_Time);

   function Raw_Value_Min return T is
   begin
      return Clock;
   end Raw_Value_Min;

   --  Depends on nothing, though it says Abstract_Time.
   function Raw_Value_Max return T is
   begin
      return 1;
   end Raw_Value_Max;
end Own_State.Timer;
