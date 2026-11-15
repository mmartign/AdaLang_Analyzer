--  What verification_join_predicates proves, where it does not hold: the
--  predicate bounds Len by 16, it does not make it 0; a type without the
--  predicate says nothing of the rate after the if. GNATprove 16.1.0
--  refuses both assertions.
package Verification_Mutation_Join_Predicates with SPARK_Mode is

   type Inner is private;

   function Rate_Of (I : Inner) return Natural;

   procedure Step (I : in out Inner; V : Natural)
     with Post => Rate_Of (I) = Rate_Of (I'Old);

   type Ctx is private;

   type Plain is record
      In_Ctx : Inner;
      Len    : Natural;
   end record;

   procedure Update (C : in out Ctx; N : Natural);

   procedure Update_Plain (C : in out Plain; N : Natural);

private

   type Inner is record
      Rate : Natural;
      Acc  : Natural;
   end record;

   function Rate_Of (I : Inner) return Natural is (I.Rate);

   type Ctx is record
      In_Ctx : Inner;
      Len    : Natural;
   end record
     with Predicate => Len <= 16 and 16 = (Rate_Of (In_Ctx) - 4) / 8
                       and (Rate_Of (In_Ctx) - 4) mod 8 = 0;

end Verification_Mutation_Join_Predicates;
