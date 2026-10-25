generic
   Log : Natural;
package Verification_Generic_Inner
  with SPARK_Mode
is
   Bits : constant Positive := 2**Log;

   function Spread (X : Natural) return Natural;
end Verification_Generic_Inner;
