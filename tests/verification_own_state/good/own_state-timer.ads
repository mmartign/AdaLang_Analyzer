--  States of the child itself, Part_Of the parent's: in the child, and in
--  a sibling that withs it, they are what the code names.
private package Own_State.Timer
  with SPARK_Mode,
       Abstract_State =>
         ((Timer_State with Part_Of => Own_State.State),
          (Abstract_Time with Part_Of => Own_State.State,
                              External => Async_Writers))
is
   function Raw_Value_Min return T
   with Volatile_Function, Global => (Input => Abstract_Time),
        Depends => (Raw_Value_Min'Result => Abstract_Time);

   function Raw_Value_Max return T
   with Volatile_Function, Global => (Input => Abstract_Time),
        Depends => (Raw_Value_Max'Result => Abstract_Time);
end Own_State.Timer;
