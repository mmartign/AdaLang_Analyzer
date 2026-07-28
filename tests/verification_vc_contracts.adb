procedure Verification_VC_Contracts
  (X      : Integer;
   Result : out Integer)
  with SPARK_Mode,
       Post => Result = X
is
   procedure Needs_Reflexive (Value : Integer)
     with Global => null,
          Pre    => Value = Value
   is
   begin
      null;
   end Needs_Reflexive;
begin
   Needs_Reflexive (X);
   Result := X;
end Verification_VC_Contracts;
