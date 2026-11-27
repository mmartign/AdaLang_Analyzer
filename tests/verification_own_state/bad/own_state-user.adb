package body Own_State.User
  with SPARK_Mode
is
   --  Depends on nothing, though it says Timer.Abstract_Time.
   procedure Sample (Value : out T) is
   begin
      Value := 0;
   end Sample;
end Own_State.User;
