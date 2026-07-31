procedure Volatile_Register_Writes_Clean is
   --  A volatile object models a memory-mapped hardware register: each
   --  write is itself the observable effect, whether or not the enclosing
   --  Ada code ever reads the object back, and whether or not consecutive
   --  writes carry the same value (a watchdog kick, or a deliberate
   --  double-write to satisfy a timing or deassert requirement). None of
   --  this is the copy-paste mistake these checks are designed to catch on
   --  an ordinary variable.
   Watchdog_Kick : Integer with Volatile;
begin
   Watchdog_Kick := 16#55#;
   Watchdog_Kick := 16#55#;
end Volatile_Register_Writes_Clean;
