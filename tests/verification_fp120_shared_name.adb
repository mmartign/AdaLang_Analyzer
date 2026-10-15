package body Verification_FP120_Shared_Name with SPARK_Mode => On is

   function Get_Y (V : T) return Integer is
   begin
      return V.Y;
   end Get_Y;

   --  The object declared inside has the name of the parameter and of the
   --  component. The two records agree in X and not in Y: for
   --  Inner_Object ((X => 1, Y => 3)) the first assertion fails.
   procedure Inner_Object (X : T) is
   begin
      declare
         X : constant T := (X => 1, Y => 2);
      begin
         if X.X = Inner_Object.X.X then
            pragma Assert (Get_Y (X) = Get_Y (Inner_Object.X));
         end if;
         pragma Assert (Get_Y (X) = Get_Y (X));
      end;
   end Inner_Object;

   procedure Needs (A, B : T) is
   begin
      null;
   end Needs;

   --  The same with one object: in the precondition of Needs, A and B are
   --  the parts X.Left and X.Right of the caller's X, each of which was the
   --  component X of that part. For ((X => 1, Y => 2), (X => 1, Y => 3))
   --  the precondition fails.
   procedure Two_Parts (X : Pair) is
   begin
      if X.Left.X = X.Right.X then
         Needs (X.Left, X.Right);
      end if;
   end Two_Parts;

   procedure Nothing with Global => null is
   begin
      null;
   end Nothing;

   --  X'Constrained and the Boolean component X: after a call both are
   --  given a symbol of their own, which was the same one. For an
   --  unconstrained actual whose component X is True the assertion fails.
   procedure Constrained (X : in out D) is
   begin
      if X.X /= X'Constrained then
         null;
      end if;
      Nothing;
      if X.X then
         pragma Assert (X'Constrained);
      end if;
   end Constrained;

   procedure Constrained_After_Call (V : in out D) is
   begin
      Constrained (V);
   end Constrained_After_Call;

end Verification_FP120_Shared_Name;
