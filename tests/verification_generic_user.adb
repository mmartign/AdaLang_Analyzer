package body Verification_Generic_User
  with SPARK_Mode
is
   function Share (X : Natural) return Natural is
   begin
      return X / (Lanes.Bits / 8);
   end Share;
end Verification_Generic_User;
