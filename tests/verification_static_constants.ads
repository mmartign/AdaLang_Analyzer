--  A constant declared outside the subprogram, whose initializer is
--  written with literals, named numbers and other such constants, has the
--  value of its initializer taken in its own type: a typed constant is no
--  more variable than a named number. The Ok_* subprograms rest on such
--  values, modular ones among them. The Bad_* subprograms read a variable,
--  a constant initialized from it, a deferred constant, and claim of a
--  modular constant the value its initializer would have without wrapping.
with Interfaces; use type Interfaces.Unsigned_8;

package Verification_Static_Constants
  with SPARK_Mode
is
   Log   : constant Natural := 6;
   Bits  : constant Positive := 2**Log;
   Bytes : constant Positive := Bits / 8;
   Lane  : constant Positive := Bytes * 5;
   Wrap  : constant Interfaces.Unsigned_8 := (200 + 100) / 2;
   Top   : constant Interfaces.Unsigned_8 := 0 - 1;

   type Lanes is array (1 .. Lane) of Natural;

   Counter  : Natural := 8;
   From_Var : constant Natural := Counter;
   Hidden   : constant Natural;

   procedure Ok_Divisor (X : Natural; Y : out Natural)
     with Global => null;
   procedure Ok_Assert
     with Global => null;
   procedure Ok_Modular (Y : out Natural)
     with Global => null;
   procedure Ok_Index (A : in out Lanes)
     with Global => null;

   procedure Bad_Variable (W : out Integer)
     with Global => (Input => Counter);
   procedure Bad_From_Variable (W : out Integer)
     with Global => (Input => From_Var);
   procedure Bad_Deferred (W : out Integer)
     with Global => null;
   procedure Bad_Modular
     with Global => null;

private
   Hidden : constant Natural := 0;
end Verification_Static_Constants;
