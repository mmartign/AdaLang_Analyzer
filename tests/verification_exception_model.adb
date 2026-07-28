procedure Verification_Exception_Model
  with SPARK_Mode
is
   X : Integer := 1;
   Y : Integer;

   procedure Mutate
     with SPARK_Mode,
          Global => (In_Out => X)
   is
   begin
      X := 0;
      raise Constraint_Error;
   end Mutate;
begin
   Mutate;
   Y := 1 / X;
exception
   when Constraint_Error =>
      Y := 1 / X;
end Verification_Exception_Model;
