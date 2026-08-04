procedure Verification_Global_Aspect_Reference_Guard (Arg : Integer) is
   X : Integer;
   Y : Integer;

   procedure Bump
     with Global => (In_Out => (X));

   procedure Bump is
   begin
      X := X + Arg;
   end Bump;

begin
   X := 0;
   Bump;
   Y := Y + 1;
end Verification_Global_Aspect_Reference_Guard;
