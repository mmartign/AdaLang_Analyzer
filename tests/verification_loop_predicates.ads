--  The predicate of what a loop writes holds at the head of the loop: a
--  parameter whose components a loop changes keeps the predicate of its
--  type each time round and after the loop, as GNATprove has it. GNATprove
--  16.1.0 proves every assertion.
package Verification_Loop_Predicates with SPARK_Mode is

   type Ctx is private;

   function Rate_Of (C : Ctx) return Natural;

   procedure Fill (C : in out Ctx; N : Natural) with Pre => N < 1_000;

   procedure Fill_Unbounded (C : in out Ctx; N : Natural)
     with Pre => N < 1_000;

private

   type Ctx is record
      Len  : Natural;
      Rate : Natural;
   end record
     with Predicate => Len <= Rate / 8 and Rate in 64 .. 1_600;

   function Rate_Of (C : Ctx) return Natural is (C.Rate);

end Verification_Loop_Predicates;
