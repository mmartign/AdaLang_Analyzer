--  Proof-path evidence: contracts written on a separate spec narrow the
--  body's own parameters (FP-085). The spec's precondition reaches the
--  body of the conforming overload only -- never a same-name overload
--  without one -- and a spec postcondition is decided against the body's
--  exit state, so a true one proves and a false one never does.
package body Verification_PP_Spec_Contracts with SPARK_Mode is
   procedure Inc (X : Integer; Sink : out Integer) is
   begin
      Sink := X + 1;
   end Inc;

   procedure Inc (X : Long_Integer; Sink : out Long_Integer) is
   begin
      Sink := X + 2;
   end Inc;

   procedure Clamp (X : Integer; Sink : out Integer) is
   begin
      Sink := X + 3;
   end Clamp;

   procedure Bump (X : in out Integer) is
   begin
      X := X + 1;
   end Bump;

   procedure Bump_Wrong (X : in out Integer) is
   begin
      X := X + 1;
   end Bump_Wrong;
end Verification_PP_Spec_Contracts;
