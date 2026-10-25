--  A generic unit is analysed once more for each instance of it in the
--  run, with the values of its actuals: the instances of
--  Verification_Instance_Passes give Log 6 and 3 and a Count up to 100,
--  for which every check of Spread and Step holds.
generic
   Log : Natural;
   type Count is range <>;
package Verification_Generic_Lanes
  with SPARK_Mode
is
   Bits : constant Positive := 2**Log;

   function Spread (X : Natural) return Natural;

   function Step (C : Count) return Count
     with Pre => C in 0 .. 9;
end Verification_Generic_Lanes;
