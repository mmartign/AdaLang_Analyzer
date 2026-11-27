--  The parent: its state is refined in a body that neither child sees.
package Own_State
  with SPARK_Mode, Abstract_State => (State with External => Async_Writers)
is
   type T is mod 2 ** 64;
end Own_State;
