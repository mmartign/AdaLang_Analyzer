--  A function in SPARK has no side effects, so a call to it leaves facts
--  about globals in place. SPARK_Mode can reach the function from a pragma
--  before its unit (By_Unit) or from the project's configuration pragmas
--  (By_Project); a unit that opts out (Unmarked) gets no such credit.
with By_Project; use By_Project;
with By_Unit;    use By_Unit;
with Unmarked;   use Unmarked;

procedure Verification_SPARK_Mode_Sources
  (N    : Integer;
   Sink : out Integer)
is
begin
   Unit_Level := 5;
   Sink := Unit_Probe (N);
   Sink := 10 / Unit_Level;

   Project_Level := 5;
   Sink := Project_Probe (N);
   Sink := 10 / Project_Level;

   Unmarked_Level := 5;
   Sink := Unmarked_Probe (N);
   Sink := 10 / Unmarked_Level;
end Verification_SPARK_Mode_Sources;
