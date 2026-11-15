package body Verification_Join_Predicates with SPARK_Mode is

   procedure Step (I : in out Inner; V : Natural) is
   begin
      I.Acc := V;
   end Step;

   procedure Update (C : in out Ctx; N : Natural) is
   begin
      if N > 3 then
         Step (C.In_Ctx, N);
      end if;
      pragma Assert (Rate_Of (C.In_Ctx) = 132);
   end Update;

end Verification_Join_Predicates;
