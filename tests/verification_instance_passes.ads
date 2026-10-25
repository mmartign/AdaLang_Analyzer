with Verification_Generic_Lanes;
with Verification_Generic_Lanes.Wide;
with Verification_Generic_Narrow;
with Verification_Generic_Outer;
with Verification_Generic_User;

package Verification_Instance_Passes
  with SPARK_Mode
is
   type Small is range 0 .. 100;
   type Tiny is range 0 .. 5;

   package L6 is new Verification_Generic_Lanes (6, Small);
   package L3 is new Verification_Generic_Lanes (Log => 3, Count => Small);
   package L6_Wide is new L6.Wide;
   package L6_User is new Verification_Generic_User (L6);

   package N6 is new Verification_Generic_Narrow (6, Small);
   package N2 is new Verification_Generic_Narrow (2, Small);
   package N6_Tiny is new Verification_Generic_Narrow (6, Tiny);

   package O6 is new Verification_Generic_Outer (6);
end Verification_Instance_Passes;
