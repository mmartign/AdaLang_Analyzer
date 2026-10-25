--  A child of the generic unit: its formals are those of the instance of
--  its parent it is instantiated from, Log 6 only.
generic
package Verification_Generic_Lanes.Wide
  with SPARK_Mode
is
   function Part (X : Natural) return Natural;
end Verification_Generic_Lanes.Wide;
