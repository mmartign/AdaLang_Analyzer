--  Proof-path evidence: symbolic array bounds. An index into an object
--  whose bounds no declaration fixes -- an unconstrained formal here --
--  proves when the precondition, a guard, the object's length or a loop
--  over its bounds places the index between the object's own 'First and
--  'Last. One step outside those bounds, or the same index into another
--  object, proves nothing.
procedure Verification_PP_Index_Symbolic_Bounds
  (Data  : String;
   Other : String;
   Given : Integer;
   Probe : Integer;
   Sink  : out Integer)
with
  SPARK_Mode,
  Pre => Given in Data'Range
is
begin
   Sink := Character'Pos (Data (Given));
   Sink := Character'Pos (Data (Given + 1));
   Sink := Character'Pos (Other (Given + 0));

   if Probe >= Data'First and then Probe <= Data'Last then
      Sink := Character'Pos (Data (Probe));
   end if;
   if Probe >= Data'First then
      Sink := Character'Pos (Data (Probe + 0));
   end if;

   if Data'Length > 1 then
      Sink := Character'Pos (Data (Data'First + 1));
      Sink := Character'Pos (Data (Data'Last + 1));
   end if;

   for Step in Data'First .. Data'Last - 1 loop
      Sink := Character'Pos (Data (Step + 1));
      Sink := Character'Pos (Data (Step + 2));
   end loop;
end Verification_PP_Index_Symbolic_Bounds;
