--  A sibling that withs the child and names its state.
with Own_State.Timer;

private package Own_State.User
  with SPARK_Mode
is
   procedure Sample (Value : out T)
   with Global => (Input => Own_State.Timer.Abstract_Time),
        Depends => (Value => Own_State.Timer.Abstract_Time);
end Own_State.User;
