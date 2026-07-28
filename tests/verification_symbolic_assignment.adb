procedure Verification_Symbolic_Assignment (X : Integer)
  with SPARK_Mode,
       Pre => X <= 2_147_483_645
is
   Y : Integer;
   Z : Integer;

   procedure Needs_Successor
     (Successor : Integer;
      Original  : Integer)
     with Global => null,
          Pre    =>
            Original <= 2_147_483_646
            and then Successor = Original + 1
   is
   begin
      null;
   end Needs_Successor;
begin
   Y := X + 1;
   Z := Y + 1;
   pragma Assert (Z = X + 2);
   Needs_Successor (Y, X);
end Verification_Symbolic_Assignment;
