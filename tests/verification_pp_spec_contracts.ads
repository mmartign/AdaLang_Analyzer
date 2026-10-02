--  Proof-path evidence: contracts on a separate spec (FP-085; see the body).
package Verification_PP_Spec_Contracts with SPARK_Mode is
   procedure Inc (X : Integer; Limit : Integer; Sink : out Integer)
     with Pre => X >= 0 and then X <= Limit and then Limit <= 10;
   procedure Inc (X : Long_Integer; Sink : out Long_Integer);
   procedure Clamp (X : Integer; Sink : out Integer)
     with Pre => X >= 0 and then X <= 10;
   procedure Bump (X : in out Integer; Floor : Integer)
     with Pre => Floor >= 0 and then X >= Floor and then X <= 10,
          Post => X >= 1;
   procedure Bump_Wrong (X : in out Integer)
     with Pre => X in 0 .. 10, Post => X >= 2;
end Verification_PP_Spec_Contracts;
