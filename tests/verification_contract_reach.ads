--  What a contract reaches: the precondition of a generic subprogram, in
--  its body; the predicate of the subtype of a component of a parameter,
--  on entry (a component of a component, one of a private type whose full
--  view has it); an expression function called through a renaming; a power
--  whose exponent is a formal bound to a numeral. GNATprove 16.1.0 proves
--  every check.
package Verification_Contract_Reach with SPARK_Mode is

   subtype Small is Integer range 0 .. 100;

   function Half (X : Small) return Small is (X / 2)
     with Pre => X mod 2 = 0;

   generic
      with procedure Log (V : Integer);
   procedure Generic_Half (X : Integer)
     with Pre => X in 0 .. 100 and then X mod 2 = 0;

   type Pair is record
      Low, High : Integer;
   end record
     with Dynamic_Predicate => Pair.Low < Pair.High;

   type Holder is record
      P : Pair;
      N : Integer;
   end record;

   type Outer is record
      H : Holder;
   end record;

   function Spread (H : Holder) return Positive
     with Pre => H.P.Low >= 0 and then H.P.High <= 1_000;

   function Deep_Spread (O : Outer) return Positive
     with Pre => O.H.P.Low >= 0 and then O.H.P.High <= 1_000;

   type Session is private;

   function Width (S : Session) return Natural;

   type Base_Integer is range 0 .. 2 ** 63 - 1;

   function Fits_Into (V : Base_Integer; Bits : Natural) return Boolean is
     (if Bits < Base_Integer'Size then V < 2 ** Bits);

   function Fits (V : Base_Integer; Bits : Natural) return Boolean
     renames Fits_Into;

   type Nibble is range 0 .. 15;

   procedure Store (V : Base_Integer) with Pre => Fits (V, 4);

   procedure Store_Nibble (N : Nibble);

private

   type Window is record
      First, Last : Natural;
   end record
     with Dynamic_Predicate => Window.First <= Window.Last;

   type Session is record
      W : Window;
   end record;

end Verification_Contract_Reach;
