--  FP-094: declaring or leaving the scope of a controlled object runs its
--  Initialize and Finalize, and declaring a record runs its component
--  defaults. Here each of those zeroes Level, at a point where the source
--  shows no call, so no division by Level in a subprogram that declares
--  such an object may be proved. A record of plain scalars runs nothing,
--  and With_Plain_Record still proves.
package body Verification_FP094_Implicit_Code is
   overriding procedure Initialize (Object : in out Guard) is
   begin
      Level := 0;
   end Initialize;

   overriding procedure Finalize (Object : in out Guard) is
   begin
      Level := 0;
   end Finalize;

   function Reset return Integer is
   begin
      Level := 0;
      return 1;
   end Reset;

   procedure At_Scope_Exit (N : Integer; Sink : out Integer) is
   begin
      declare
         Held : Guard;
         pragma Unreferenced (Held);
      begin
         Level := 5 + N - N;
      end;
      Sink := 10 / (Level + 0);
   end At_Scope_Exit;

   procedure At_Declaration (N : Integer; Sink : out Integer) is
   begin
      Level := 5;
      declare
         Held : Guard;
         pragma Unreferenced (Held);
      begin
         Sink := 10 / (Level - 0) + N;
      end;
   end At_Declaration;

   procedure At_Default (N : Integer; Sink : out Integer) is
   begin
      Level := 5;
      declare
         Item : Defaulted;
      begin
         Sink := 10 / (0 + Level) + Item.Field + N;
      end;
   end At_Default;

   procedure With_Plain_Record (N : Integer; Sink : out Integer) is
   begin
      Level := 5;
      declare
         Pair : Plain_Pair;
      begin
         Sink := 10 / Level + Pair.Left + N;
      end;
   end With_Plain_Record;
end Verification_FP094_Implicit_Code;
