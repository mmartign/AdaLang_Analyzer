--  Objects with relaxed initialization (SPARK RM 6.10) may have parts with
--  no value: a read of a part is checked where it is, and X'Initialized
--  says that every part has one. What is known of a whole object: it has a
--  value in every part where it is given a value that has, and where a
--  condition known to hold says X'Initialized -- a precondition, an
--  assumption, in "and then" or under a double "not". A whole copy into a
--  relaxed object reads no value, and a relaxed out parameter may be left
--  with parts that have none. A parameter of a scalar type has a value on
--  entry, its actual being checked at the call, and a literal has one,
--  whatever its type. Every claim here holds.
--  verification_mutation_relaxed_initialization has those that do not.
package Verification_Relaxed_Initialization
  with SPARK_Mode
is
   type Arr is array (1 .. 4) of Integer;
   type Rel is array (1 .. 4) of Integer with Relaxed_Initialization;
   type Soft_Int is new Integer with Relaxed_Initialization;
   type Soft_Flag is new Boolean with Relaxed_Initialization;
   type Flags is array (1 .. 4) of Soft_Flag;

   procedure Fill (Filled : out Arr)
     with Relaxed_Initialization => Filled, Post => Filled'Initialized;
   procedure Whole_Assert;
   procedure Copy_Whole (Target : out Arr; Origin : Arr)
     with Relaxed_Initialization => (Target, Origin);
   function Pre_Whole (Given : Arr) return Integer
     with Relaxed_Initialization => Given, Pre => Given'Initialized;
   function Pre_Type (Typed : Rel) return Integer
     with Pre => Typed'Initialized;
   function Pre_Both (First, Second : Arr) return Integer
     with Relaxed_Initialization => (First, Second),
          Pre => First'Initialized and then Second'Initialized;
   function Assumed (Hoped : Arr) return Integer
     with Relaxed_Initialization => Hoped;
   function Negated (Twice : Arr) return Integer
     with Relaxed_Initialization => Twice;
   procedure Scalar_In_Out (Counter : in out Soft_Int)
     with Pre => Counter < Soft_Int'Last;
   function Literal_Flags return Boolean;
end Verification_Relaxed_Initialization;
