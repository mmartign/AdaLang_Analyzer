package body Verification_Mutation_Contract_Reach with SPARK_Mode is

   procedure Generic_Any (X : Integer) is
   begin
      Log (Half (X));
   end Generic_Any;

   procedure Ignore (V : Integer) is null;

   procedure Any_Ignored is new Generic_Any (Ignore);
   pragma Unreferenced (Any_Ignored);

   function Loose_Spread (H : Holder) return Positive is
   begin
      return H.L.High - H.L.Low;
   end Loose_Spread;

   function Plain_Spread (H : Holder) return Positive is
   begin
      return H.P.High - H.P.Low;
   end Plain_Spread;

   procedure Store (V : Base_Integer) is null;

   procedure Store_Wide (N : Five_Bits) is
   begin
      Store (Base_Integer (N));
   end Store_Wide;

   procedure Need_Positive (X : Integer) is null;

   procedure Swap_Call is
   begin
      Need_Positive (Swapped (3, 10));
   end Swap_Call;

   procedure Need_Nonzero (X : Octet) is null;

   procedure Wrap_Call is
   begin
      Need_Nonzero (Power (8));
   end Wrap_Call;

end Verification_Mutation_Contract_Reach;
