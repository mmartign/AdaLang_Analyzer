package body Verification_Predicate_Checks with SPARK_Mode is

   procedure Ok_Value (N : Natural; S : out Size_8) is
   begin
      S := N * 8;
   end Ok_Value;

   procedure Bad_Value (N : Natural; S : out Size_8) is
   begin
      S := N * 8 + 1;
   end Bad_Value;

   --  The predicate holds on entry, and the other components keep it.
   procedure Ok_Part (Ok_P : in out Ctx) is
   begin
      Ok_P.Used := 0;
   end Ok_Part;

   procedure Bad_Part (Bad_P : in out Ctx) is
   begin
      Bad_P.Used := Bad_P.Rate;
   end Bad_Part;

   procedure Touch (X : in out Natural) is
   begin
      X := 0;
   end Touch;

   --  A call that writes one component leaves the others as they were.
   procedure Ok_Through (Ok_T : in out Ctx) is
   begin
      Touch (Ok_T.Inner);
   end Ok_Through;

   procedure Ok_Widen (Ok_W : in out Bare) is
   begin
      if Ok_W.High < Natural'Last then
         Ok_W.High := Ok_W.High + 1;
      end if;
   end Ok_Widen;

   procedure Bad_Widen (Bad_W : in out Bare) is
   begin
      if Bad_W.High < Natural'Last then
         Bad_W.Low := Bad_W.High + 1;
      end if;
   end Bad_Widen;

   --  A component not written yet has a value of its subtype: Count < Limit
   --  for any Limit once Count is 0.
   procedure Ok_Init (Ok_I : out Pair) is
   begin
      Ok_I.Count := 0;
      Ok_I.Limit := 10;
   end Ok_Init;

   procedure Bad_Init (Bad_I : out Pair) is
   begin
      Bad_I.Limit := 1;
      Bad_I.Count := 1;
   end Bad_Init;

   function Ok_Result (N : Natural) return Size_8 is
   begin
      return 8 * N;
   end Ok_Result;

   procedure Take (S : Size_8) is
   begin
      null;
   end Take;

   procedure Ok_Actual (N : Natural) is
   begin
      Take (2 * N * 4);
   end Ok_Actual;

   procedure Bad_Actual (N : Natural) is
   begin
      Take (N * 4);
   end Bad_Actual;

   procedure Ok_Decl (N : Natural; S : out Natural) is
      D : constant Size_8 := 4 * N * 2;
   begin
      S := D;
   end Ok_Decl;

   procedure Ok_Kept (S : Size_8; T : out Size_8) is
   begin
      T := S;
   end Ok_Kept;

end Verification_Predicate_Checks;
