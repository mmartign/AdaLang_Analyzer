--  A formal package: its formals are those of the instance it is given,
--  Log 6. Verification_Generic_Inner is instantiated only in the body of
--  another generic unit, Verification_Generic_Outer: what it is
--  instantiated with depends on the instance of that unit, and it is left
--  as it is analysed once.
with Verification_Generic_Lanes;

generic
   with package Lanes is new Verification_Generic_Lanes (<>);
package Verification_Generic_User
  with SPARK_Mode
is
   function Share (X : Natural) return Natural;
end Verification_Generic_User;
