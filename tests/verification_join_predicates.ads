--  The predicate of an object holds where the ways of an if statement
--  meet, the branches having written parts of it: a call in one branch
--  changes a component, and the rate the predicate fixes is known after
--  the if. GNATprove 16.1.0 proves the assertion.
package Verification_Join_Predicates with SPARK_Mode is

   type Inner is private;

   function Rate_Of (I : Inner) return Natural;

   procedure Step (I : in out Inner; V : Natural)
     with Post => Rate_Of (I) = Rate_Of (I'Old);

   type Ctx is private;

   procedure Update (C : in out Ctx; N : Natural);

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

end Verification_Join_Predicates;
