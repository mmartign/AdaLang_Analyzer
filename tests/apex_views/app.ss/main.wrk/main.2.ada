--  Uses the units of the view of util.ss that this view imports.
with Counters.Limits;
procedure Main is
   use type Counters.Counter;
   Level : Counters.Counter := Counters.Limits.Top;
   Spare : Integer;
begin
   Counters.Bump (Level);
   Level := Counters.Limits.Top + 1;
   Counters.Reset (Level);
end Main;
