--  A write to elements of an array changes that array and nothing else in
--  SPARK code that takes no 'Access or 'Address of anything: what a
--  predicate or a precondition says of the elements of another array
--  stands. The Ok_* subprograms rest on such facts, and on a division by a
--  named number. The Bad_* subprograms have a fact of the array written,
--  directly or through a renaming, and of an array that may be the one
--  written by another name, outside SPARK code.
package Verification_Element_Writes
  with SPARK_Mode
is
   LM : constant := 65536;
   subtype Limb is Long_Long_Integer range 0 .. 2**40;
   type Product is array (0 .. 3) of Limb
     with Dynamic_Predicate =>
       Product (0) <= 40_000_000 and Product (1) in 0 .. 65_535;
   subtype Out_Limb is Integer range 0 .. 65_535;
   type Limbs is array (0 .. 3) of Out_Limb;
   subtype Any_Limb is Integer range -2**20 .. 2**20;
   type Cells is array (0 .. 3) of Integer;

   procedure Ok_Carry (D : Product; R : out Limbs);
   procedure Bad_Same (A : in out Cells; W : out Integer)
     with Pre => A (0) = 0;
   procedure Bad_Renaming (A : in out Cells; W : out Integer)
     with Pre => A (0) = 0;
   procedure Bad_Other_Name (A, B : in out Cells; W : out Integer)
     with Pre => A (0) = 0;
end Verification_Element_Writes;
