--  The claims about calls of generic formal subprograms that do not hold:
--  each call fails for an instance, or for all, and GNATprove refuses it.
--  None may be taken as proved: not through the instance that holds, not by
--  a name that means something else, and not because an actual seems to ask
--  nothing when it asks in a way that is not an aspect Pre.
package Verification_Mutation_Formal_Contracts
  with SPARK_Mode
is
   function Upto_3 (X : Integer; Amount : Natural) return Integer
     with Pre => Amount <= 3;
   function Upto_9 (Y : Integer; By : Natural) return Integer
     with Pre => By <= 9;
   function Free (X : Integer; Amount : Natural) return Integer;

   function Swapped (Amount : Integer; X : Natural) return Integer
     with Pre => X <= 3;

   function Over (X : Integer; Amount : Natural) return Integer;
   function Over (X : Boolean; Amount : Natural) return Integer
     with Pre => Amount <= 1;

   function By_Pragma (X : Integer; Amount : Natural) return Integer;
   pragma Precondition (Amount <= 1);

   type Root is tagged null record;
   function Prim (V : Root; N : Natural) return Integer
     with Pre'Class => N <= 1;
   function Plain_Pre (V : Integer; N : Natural) return Integer
     with Pre => N <= 9;

   generic
      Limit : Natural;
   function Made (X : Integer; Amount : Natural) return Integer
     with Pre => Amount <= Limit;

   procedure Act (V : in out Integer; N : Natural)
     with Pre => N <= 2;

   --  Fails for one instance of two.
   generic
      with function Some_Hold (V : Integer; N : Natural) return Integer;
   package Through_Some is
      function Five (V : Integer) return Integer;
      function Open (V : Integer; K : Natural) return Integer;
   end Through_Some;

   --  An actual without a precondition must not stand for the other.
   generic
      with function Free_Beside (V : Integer; N : Natural) return Integer;
   package Through_Free is
      function Open (V : Integer; K : Natural) return Integer;
   end Through_Free;

   --  Read by name, X would be the 0 given to the first formal.
   generic
      with function Cross (X : Integer; Amount : Natural) return Integer;
   package Through_Cross is
      function Open (K : Natural) return Integer;
   end Through_Cross;

   --  Read as the first overload, nothing would be asked.
   generic
      with function Picked (V : Boolean; N : Natural) return Integer;
   package Through_Picked is
      function Three (V : Boolean) return Integer;
   end Through_Picked;

   generic
      with function By_Other (V : Integer; N : Natural) return Integer;
   package Through_Pragma is
      function Two (V : Integer) return Integer;
   end Through_Pragma;

   generic
      type T is private;
      with function By_Class (V : T; N : Natural) return Integer;
   package Through_Class is
      function Two (V : T) return Integer;
   end Through_Class;

   --  The contract of a generic subprogram is on the unit, not the instance.
   generic
      with function By_Instance (V : Integer; N : Natural) return Integer;
   package Through_Instance is
      function Two (V : Integer) return Integer;
   end Through_Instance;

   --  Two instances of Bounded at one place, with different limits.
   generic
      Limit : Natural;
   package Bounded is
      function F (X : Integer; Amount : Natural) return Integer
        with Pre => Amount <= Limit;
   end Bounded;

   generic
      with function Twice (V : Integer; N : Natural) return Integer;
   package Through_Twice is
      function Five (V : Integer) return Integer;
   end Through_Twice;

   generic
      with procedure Step (V : in out Integer; N : Natural);
   package Through_Step is
      procedure Seven (V : in out Integer);
   end Through_Step;

   --  A generic unit inside a generic unit: one instance of the outer one
   --  is not enough, and neither is one of the inner one.
   generic
      with function Rot (V : Integer; N : Natural) return Integer;
   package Outer is
      generic
         Steps : Natural;
      function Run (V : Integer) return Integer;
      function Seven (V : Integer) return Integer;
   end Outer;

   --  One instance takes the default, which asks for more.
   function Default (V : Integer; N : Natural) return Integer
     with Pre => N <= 1;

   generic
      with function Default (V : Integer; N : Natural) return Integer is <>;
   package Through_Default is
      function Two (V : Integer) return Integer;
   end Through_Default;

end Verification_Mutation_Formal_Contracts;
