procedure Verification_VC_Derived_Overflow_Base
  with SPARK_Mode
is
   type Length is new Natural;
   type Index is new Length range 1 .. Length'Last;
   X : constant Index := Index'First;
   Y : Index;
begin
   Y := X - 2 + 5;
   pragma Assert (Y = 4);
end Verification_VC_Derived_Overflow_Base;
