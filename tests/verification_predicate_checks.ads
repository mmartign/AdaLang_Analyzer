--  Predicate checks: where a value is given to an object whose subtype has a
--  predicate, or to a part of one, the object keeps the predicate. The
--  checks of the subprograms named Ok_* hold; those of the subprograms
--  named Bad_* do not: a value outside the predicate (Bad_Value,
--  Bad_Actual), a component that breaks the predicate of its record
--  (Bad_Part, Bad_Widen), the components of an object of mode out written
--  in an order that leaves the predicate false (Bad_Init). Ok_Kept gives
--  an object the value of another of the same subtype: no check is raised
--  there, as GNATprove raises none. GNATprove proves the checks of the
--  Ok_* subprograms and none of the checks of the Bad_* ones.
package Verification_Predicate_Checks with SPARK_Mode is

   subtype Size_8 is Natural range 0 .. 64
     with Dynamic_Predicate => Size_8 mod 8 = 0;

   type Ctx is record
      Rate     : Positive;
      Capacity : Natural;
      Used     : Natural;
      Inner    : Natural;
   end record
     with Predicate => Used < Rate and then Capacity = 100 - Rate;

   --  A predicate that names the components of the type alone.
   type Bare is record
      Low, High : Natural;
   end record
     with Predicate => Low <= High;

   type Pair is record
      Count : Natural;
      Limit : Positive;
   end record
     with Predicate => Count < Limit;

   procedure Ok_Value (N : Natural; S : out Size_8)
     with Pre => N <= 8;

   procedure Bad_Value (N : Natural; S : out Size_8)
     with Pre => N <= 8;

   procedure Ok_Part (Ok_P : in out Ctx);

   procedure Bad_Part (Bad_P : in out Ctx);

   procedure Touch (X : in out Natural)
     with Post => X = 0;

   procedure Ok_Through (Ok_T : in out Ctx);

   procedure Ok_Widen (Ok_W : in out Bare);

   procedure Bad_Widen (Bad_W : in out Bare);

   procedure Ok_Init (Ok_I : out Pair);

   procedure Bad_Init (Bad_I : out Pair);

   function Ok_Result (N : Natural) return Size_8
     with Pre => N <= 8;

   procedure Take (S : Size_8);

   procedure Ok_Actual (N : Natural)
     with Pre => N <= 8;

   procedure Bad_Actual (N : Natural)
     with Pre => N <= 8;

   procedure Ok_Decl (N : Natural; S : out Natural)
     with Pre => N <= 8;

   procedure Ok_Kept (S : Size_8; T : out Size_8);

end Verification_Predicate_Checks;
