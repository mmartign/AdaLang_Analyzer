--  FP-124: an iteration other than over a discrete range or an array -- of
--  a loop, a quantified expression, an aggregate -- calls the operations of
--  an iterator or of an Iterable type, code the source shows no call to.
--  Element here counts its calls. Each assertion of Loop_Over, Assert_Over
--  and Quantify_Over fails at run time; those of Range_Loop and Array_Loop
--  hold.
package Verification_FP124_Iteration is

   Calls : Integer := 0;

   type Bag is record
      Count : Integer := 3;
   end record
     with Iterable => (First       => First,
                       Next        => Next,
                       Has_Element => Has_Element,
                       Element     => Element);

   function First (B : Bag) return Integer;
   function Next (B : Bag; C : Integer) return Integer;
   function Has_Element (B : Bag; C : Integer) return Boolean;
   function Element (B : Bag; C : Integer) return Integer;

   type Arr is array (1 .. 3) of Integer;

   procedure Loop_Over (B : Bag);
   procedure Assert_Over (B : Bag);
   procedure Quantify_Over (B : Bag);
   procedure Range_Loop;
   procedure Array_Loop (A : Arr);

end Verification_FP124_Iteration;
