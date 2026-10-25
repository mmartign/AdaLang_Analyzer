--  The same as Verification_Generic_Lanes, with an instance more: Log 2,
--  for which Bits / 8 is 0, and a Count up to 5, which C + 1 may exceed.
generic
   Log : Natural;
   type Count is range <>;
package Verification_Generic_Narrow
  with SPARK_Mode
is
   Bits : constant Positive := 2**Log;

   function Spread (X : Natural) return Natural;

   function Step (C : Count) return Count
     with Pre => C in 0 .. 9;
end Verification_Generic_Narrow;
