procedure Verification_VC_Call_Statement_Body (X_In : Integer) is
   function Double (Value : Integer) return Integer is
   begin
      return Value + Value;
   end Double;
   X : Integer := X_In;
begin
   pragma Assume (X >= 0 and then X <= 100);
   pragma Assert (Double (X) >= 0);
end Verification_VC_Call_Statement_Body;
