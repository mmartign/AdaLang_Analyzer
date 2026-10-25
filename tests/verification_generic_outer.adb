with Verification_Generic_Inner;

package body Verification_Generic_Outer
  with SPARK_Mode
is
   package Inner is new Verification_Generic_Inner (Log);

   function Spread (X : Natural) return Natural is (Inner.Spread (X));
end Verification_Generic_Outer;
