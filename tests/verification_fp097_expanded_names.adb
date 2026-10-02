--  FP-097: "State.Level" and "Level" are one object, as are a local and
--  its name qualified by the enclosing subprogram. A write through either
--  spelling changes what is known under the other, so the two divisions
--  after a write of zero must not be proved; a value written and read
--  under the qualified spelling is known like any other.
procedure Verification_FP097_Expanded_Names
  (N    : Integer;
   Sink : out Integer)
is
   package State is
      Level : Integer := 5;
      Other : Integer := 5;
   end State;
   use State;

   Local : Integer := 5;
begin
   Level := 5;
   State.Level := N - N;
   Sink := 10 / Level;

   Local := 5;
   Verification_FP097_Expanded_Names.Local := N - N;
   Sink := 10 / Local;

   State.Other := 5;
   Sink := 10 / State.Other;
end Verification_FP097_Expanded_Names;
