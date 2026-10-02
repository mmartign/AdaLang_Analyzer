--  Proof-path evidence: contracts written on a separate spec narrow the
--  body's own parameters (FP-085). The spec's precondition reaches the
--  body of the conforming overload only -- never a same-name overload
--  without one -- and a spec postcondition is decided against the body's
--  exit state, so a true one proves and a false one never does. Inc and
--  Bump bound X only relative to another parameter, so their obligations
--  need the solver; Clamp's comparisons give X an interval of its own.
package body Verification_PP_Spec_Contracts with SPARK_Mode is
   procedure Inc (X : Integer; Limit : Integer; Sink : out Integer) is
   begin
      Sink := 1 + X;
   end Inc;

   procedure Inc (X : Long_Integer; Sink : out Long_Integer) is
   begin
      Sink := X + 2;
   end Inc;

   procedure Clamp (X : Integer; Sink : out Integer) is
   begin
      Sink := X + 3;
   end Clamp;

   procedure Bump (X : in out Integer; Floor : Integer) is
   begin
      X := X + 1;
   end Bump;

   procedure Bump_Wrong (X : in out Integer) is
   begin
      X := X + 1;
   end Bump_Wrong;
end Verification_PP_Spec_Contracts;
