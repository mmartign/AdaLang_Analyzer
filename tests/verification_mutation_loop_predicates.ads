--  What verification_loop_predicates proves, where it does not hold: the
--  predicate allows Len up to 200, not 100; a type without a predicate
--  says nothing at the head. GNATprove 16.1.0 refuses each assertion.
package Verification_Mutation_Loop_Predicates with SPARK_Mode is

   type Ctx is private;

   type Plain is record
      Len  : Natural;
      Rate : Natural;
   end record;

   procedure Fill (C : in out Ctx; N : Natural) with Pre => N < 1_000;

   procedure Fill_Plain (C : in out Plain; N : Natural)
     with Pre => N < 1_000 and then C.Len <= C.Rate / 8
                 and then C.Rate in 64 .. 1_600;

private

   type Ctx is record
      Len  : Natural;
      Rate : Natural;
   end record
     with Predicate => Len <= Rate / 8 and Rate in 64 .. 1_600;

end Verification_Mutation_Loop_Predicates;
