package body Verification_Mutation_Call_Postcondition with SPARK_Mode is

   function Ready (Ctx : Context) return Boolean is
   begin
      return Ctx.Used < 8 and then Ctx.Data (1) < 8;
   end Ready;

   function Room (Ctx : Context; Need : Natural) return Boolean is
   begin
      return Need <= 8 and then Ctx.Used <= 8 - Need;
   end Room;

   package body Loose with SPARK_Mode => Off is
      function Poke (Target : Cells_Access) return Boolean is
      begin
         Target (1) := 9;
         return True;
      end Poke;
   end Loose;

   procedure Reset (Ctx : in out Context) is
   begin
      Ctx.Used := 0;
      Ctx.Data := (others => 0);
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

   procedure Reserve_Default (Ctx : in out Context; Need : Natural := 2) is
   begin
      Reserve (Ctx, Need);
   end Reserve_Default;

   procedure Fill (Ctx : in out Context; Need : Natural) is
   begin
      Ctx.Used := Ctx.Used + Need;
   end Fill;

   procedure Reset_And_Raise (Ctx : in out Context; Need : in out Natural) is
   begin
      Ctx.Used := 0;
      Need := 8;
   end Reset_And_Raise;

   procedure Reset_Shared (Ctx : in out Context) is
   begin
      Ctx.Used := 0;
      Shared.Used := 8;
   end Reset_Shared;

   procedure Copy (From : Context; To : in out Context) is
   begin
      To.Used := From.Used + 1;
   end Copy;

   procedure Poked (Ctx : in out Context) is
   begin
      Ctx.Used := 0;
   end Poked;

   procedure Other_Object is
      Known, Unknown : Context;
   begin
      Reset (Known);
      Step (Unknown);
   end Other_Object;

   procedure Written_After is
      Changed : Context;
   begin
      Reset (Changed);
      Changed.Data (1) := 9;
      Step (Changed);
   end Written_After;

   procedure Other_Value is
      Sized : Context;
   begin
      Reserve (Sized, 4);
      Fill (Sized, 5);
   end Other_Value;

   procedure Global_Argument is
      Asked : Context;
   begin
      Reserve (Asked, Demand);
      Demand := Demand + 1;
      Fill (Asked, Demand);
   end Global_Argument;

   procedure Argument_Written is
      Raised : Context;
      Wanted : Natural := 2;
      Before : constant Natural := Wanted;
   begin
      Reset_And_Raise (Raised, Wanted);
      Fill (Raised, Before);
   end Argument_Written;

   procedure Default_Argument is
      Defaulted : Context;
   begin
      Reserve_Default (Defaulted);
      Fill (Defaulted, 7);
   end Default_Argument;

   procedure Only_Once is
      Repeated : Context;
   begin
      Reset (Repeated);
      for Round in 1 .. 3 loop
         Step (Repeated);
      end loop;
   end Only_Once;

   procedure Global_Actual is
   begin
      Reset_Shared (Shared);
      Step (Shared);
   end Global_Actual;

   procedure Same_Object is
      Twice : Context;
   begin
      Twice.Used := 7;
      Copy (Twice, Twice);
      Step (Twice);
   end Same_Object;

   procedure Untrusted_Postcondition is
      Pointed : Context;
   begin
      Poked (Pointed);
      Step (Pointed);
   end Untrusted_Postcondition;

   procedure From_Inside is
      Local : Context;

      procedure Spoil (Ctx : in out Context) with Post => Ready (Ctx);

      procedure Spoil (Ctx : in out Context) is
      begin
         Ctx.Used := 0;
         Local.Used := 8;
      end Spoil;
   begin
      Spoil (Local);
      Step (Local);
   end From_Inside;

end Verification_Mutation_Call_Postcondition;
