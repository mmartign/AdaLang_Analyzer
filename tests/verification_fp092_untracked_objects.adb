--  FP-092: an object that another name can change, or that can change
--  with no name at all, holds no fact between two points of the program.
--  A write through a renaming or an address overlay changes the object
--  underneath; a volatile or atomic object may differ on every read. The
--  ordinary variable Plain is unaffected by any of this and still proves.
procedure Verification_FP092_Untracked_Objects
  (N    : Integer;
   Sink : out Integer)
is
   Renamed  : Integer := 5;
   Alias    : Integer renames Renamed;
   Second   : Integer := 5;
   View     : Integer renames Second;
   Overlaid : Integer := 5;
   Overlay  : Integer with Address => Overlaid'Address, Import;
   Device   : Integer := 5 with Volatile;
   Shared   : Integer := 5 with Atomic;
   Plain    : Integer := 5;
begin
   Renamed := 5;
   Alias := N - N;
   Sink := 10 / Renamed;

   View := 5;
   Second := N - N;
   Sink := 10 / View;

   Overlaid := 5;
   Overlay := N - N;
   Sink := 10 / Overlaid;

   Device := 5;
   Sink := 10 / Device;
   if Shared > 0 then
      Sink := 10 / Shared;
   end if;

   Plain := 5;
   Sink := 10 / Plain;
end Verification_FP092_Untracked_Objects;
