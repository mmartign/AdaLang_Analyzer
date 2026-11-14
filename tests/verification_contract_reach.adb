package body Verification_Contract_Reach with SPARK_Mode is

   procedure Generic_Half (X : Integer) is
   begin
      Log (Half (X));
   end Generic_Half;

   procedure Ignore (V : Integer) is null;

   procedure Half_Ignored is new Generic_Half (Ignore);
   pragma Unreferenced (Half_Ignored);

   function Spread (H : Holder) return Positive is
   begin
      return H.P.High - H.P.Low;
   end Spread;

   function Deep_Spread (O : Outer) return Positive is
   begin
      return O.H.P.High - O.H.P.Low;
   end Deep_Spread;

   function Width (S : Session) return Natural is
   begin
      return S.W.Last - S.W.First;
   end Width;

   procedure Store (V : Base_Integer) is null;

   procedure Store_Nibble (N : Nibble) is
   begin
      Store (Base_Integer (N));
   end Store_Nibble;

end Verification_Contract_Reach;
