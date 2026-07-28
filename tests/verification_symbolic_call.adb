procedure Verification_Symbolic_Call (X : Integer)
  with SPARK_Mode
is
   Y : Integer;

   procedure Replace (Value : out Integer)
     with Global => null
   is
   begin
      Value := 0;
   end Replace;
begin
   Y := X;
   Replace (Y);

   --  There is no postcondition connecting the new Y to X.
   pragma Assert (Y = X);
end Verification_Symbolic_Call;
