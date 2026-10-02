--  FP-094 (see the body): types whose objects run user code implicitly.
with Ada.Finalization;

package Verification_FP094_Implicit_Code is
   Level : Integer := 5;

   type Guard is new Ada.Finalization.Controlled with null record;
   overriding procedure Initialize (Object : in out Guard);
   overriding procedure Finalize (Object : in out Guard);

   function Reset return Integer;

   type Defaulted is record
      Field : Integer := Reset;
   end record;

   type Plain_Pair is record
      Left, Right : Integer := 1;
   end record;

   procedure At_Scope_Exit (N : Integer; Sink : out Integer);
   procedure At_Declaration (N : Integer; Sink : out Integer);
   procedure At_Default (N : Integer; Sink : out Integer);
   procedure With_Plain_Record (N : Integer; Sink : out Integer);
end Verification_FP094_Implicit_Code;
