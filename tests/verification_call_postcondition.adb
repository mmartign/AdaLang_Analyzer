package body Verification_Call_Postcondition with SPARK_Mode is

   function Ready (Ctx : Context) return Boolean is
   begin
      return Ctx.Used < 8 and then Ctx.Data (1) < 8;
   end Ready;

   function Room (Ctx : Context; Need : Natural) return Boolean is
   begin
      return Need <= 8 and then Ctx.Used <= 8 - Need;
   end Room;

   procedure Reset (Ctx : in out Context) is
   begin
      Ctx := (Used => 0, Data => (others => 0));
   end Reset;

   procedure Step (Ctx : in out Context) is
   begin
      Ctx.Data (2) := Ctx.Data (2) / 2;
   end Step;

   procedure Reserve (Ctx : in out Context; Need : Natural) is
   begin
      if Need <= 8 then
         Ctx.Used := 8 - Need;
      end if;
   end Reserve;

   procedure Fill (Ctx : in out Context; Need : Natural) is
   begin
      Ctx.Used := Ctx.Used + Need;
   end Fill;

   procedure In_Sequence is
      First : Context;
   begin
      Reset (First);
      Step (First);
      Step (Ctx => First);
   end In_Sequence;

   procedure With_Scalar (Need : Natural) is
      Sized : Context;
      Count : constant Natural := Need;
   begin
      Reset (Sized);
      Reserve (Sized, Count);
      Fill (Sized, Count);
   end With_Scalar;

   procedure After_Unknown is
      Loaded : Context;
   begin
      Load (Loaded);
      Step (Loaded);
   end After_Unknown;

   procedure In_Loop is
      Turning : Context;
   begin
      Reset (Turning);
      for Round in 1 .. 3 loop
         pragma Loop_Invariant (Ready (Turning));
         Step (Turning);
      end loop;
   end In_Loop;

end Verification_Call_Postcondition;
