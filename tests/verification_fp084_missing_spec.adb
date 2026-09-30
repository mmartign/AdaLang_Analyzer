--  FP-084 regression: a package body whose spec is deliberately absent, so
--  Libadalang cannot resolve Rec_Ptr and the fixed-point run aborts partway
--  through Aborted. Its obligations must be Unsupported, never Unreachable.
package body Verification_FP084_Missing_Spec is
   procedure Aborted (Z : Rec_Ptr; Sink : out Integer) is
   begin
      Sink := 0;
      Z.F := 1;
      Sink := Z.F + 1;
   end Aborted;
end Verification_FP084_Missing_Spec;
