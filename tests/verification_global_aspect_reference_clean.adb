procedure Verification_Global_Aspect_Reference_Clean (Arg : Integer) is
   X : Integer;

   procedure Bump
     with Global => (In_Out => (X));

   procedure Bump is
   begin
      X := X + Arg;
   end Bump;

begin
   X := 0;
   Bump;
end Verification_Global_Aspect_Reference_Clean;
