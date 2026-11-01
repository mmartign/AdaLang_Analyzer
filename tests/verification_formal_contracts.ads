--  What a call of a generic formal subprogram asks of its caller is what the
--  subprogram each instance gives the formal asks: a precondition of the
--  actual is an obligation of the call, proved when every instance in the
--  run proves it. An actual without one asks nothing. A precondition goes by
--  position, as instantiation matches the formals; names mean nothing.
--  Every claim here holds. verification_mutation_formal_contracts has those
--  that do not.
package Verification_Formal_Contracts
  with SPARK_Mode
is
   function Upto_3 (X : Integer; Amount : Natural) return Integer
     with Pre => Amount <= 3;
   function Upto_9 (Y : Integer; By : Natural) return Integer
     with Pre => By <= 9;
   function Free (X : Integer; Amount : Natural) return Integer;

   --  The names of the formals are crossed, as against Cross below.
   function Swapped (Amount : Integer; X : Natural) return Integer
     with Pre => X <= 3;

   function Over (X : Integer; Amount : Natural) return Integer;
   function Over (X : Boolean; Amount : Natural) return Integer
     with Pre => Amount <= 1;

   function Renamed_3 (X : Integer; Amount : Natural) return Integer
     renames Upto_3;

   function Completed (X : Integer; Amount : Natural) return Integer
     with Pre => Amount <= 4;

   procedure Act (V : in out Integer; N : Natural)
     with Pre => N <= 2;

   --  Several actuals, one with a renaming and one completed elsewhere.
   generic
      with function Plain (V : Integer; N : Natural) return Integer;
   package Through_Plain is
      function Two (V : Integer) return Integer;
      function Named (V : Integer) return Integer;
      function Guarded (V : Integer; K : Natural) return Integer;
   end Through_Plain;

   --  An actual without a precondition beside one with: 5 meets the only
   --  one there is.
   generic
      with function Mixed (V : Integer; N : Natural) return Integer;
   package Through_Mixed is
      function Five (V : Integer) return Integer;
   end Through_Mixed;

   generic
      with function Cross (X : Integer; Amount : Natural) return Integer;
   package Through_Cross is
      function Any (Value : Integer) return Integer;
   end Through_Cross;

   --  The profile of the formal picks the overload.
   generic
      with function Picked (V : Boolean; N : Natural) return Integer;
   package Through_Picked is
      function Zero (V : Boolean) return Integer;
   end Through_Picked;

   generic
      with procedure Step (V : in out Integer; N : Natural);
   package Through_Step is
      procedure One (V : in out Integer);
      procedure After (V : in out Integer; K : Natural)
        with Pre => K <= 1;
   end Through_Step;

   --  Two instances of Bounded give one place two meanings.
   generic
      Limit : Natural;
   package Bounded is
      function F (X : Integer; Amount : Natural) return Integer
        with Pre => Amount <= Limit;
   end Bounded;

   generic
      with function Twice (V : Integer; N : Natural) return Integer;
   package Through_Twice is
      function Two (V : Integer) return Integer;
   end Through_Twice;

   --  A generic unit inside a generic unit: its instances give both.
   generic
      with function Rot (V : Integer; N : Natural) return Integer;
   package Outer is
      generic
         Steps : Natural;
      function Run (V : Integer) return Integer;
   end Outer;

private

   function Completed (X : Integer; Amount : Natural) return Integer
   is (if Amount > 0 then X else 0);

end Verification_Formal_Contracts;
