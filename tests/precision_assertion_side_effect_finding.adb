procedure Precision_Assertion_Side_Effect_Finding is

   function Pop (Stack : in out Integer) return Boolean is
   begin
      Stack := Stack - 1;
      return Stack >= 0;
   end Pop;

   X : Integer := 5;
begin
   pragma Assert (Pop (X));
end Precision_Assertion_Side_Effect_Finding;
