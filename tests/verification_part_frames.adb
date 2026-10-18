package body Verification_Part_Frames is

   procedure Bump (X : in out Natural) with SPARK_Mode is
   begin
      X := X + 1;
   end Bump;

   procedure Reset (Ctx : in out Context) with SPARK_Mode is
   begin
      Ctx.P.Count := 1;
   end Reset;

   procedure Needs_Free (S : Slots) with SPARK_Mode is
   begin
      null;
   end Needs_Free;

   procedure Invariant_Kept (Ctx : in out Context; Key : String)
     with SPARK_Mode
   is
      function Entry_Free return Boolean is
        (Ctx.P.Slots.S1 = null and Ctx.P.Slots.S2 = null) with Ghost;
      function Exit_Free return Boolean is
        (Ctx.P.Slots.S1 = null and Ctx.P.Slots.S2 = null) with Ghost;
   begin
      pragma Assert (Entry_Free);
      pragma Assert (Key /= "stop");
      Needs_Free (Ctx.P.Slots);
      if Key = "go" then
         Ctx.P.Next := 1;
      else
         Ctx.P.Next := 2;
      end if;
      Bump (Ctx.P.Count);
      pragma Assert (Exit_Free);
   end Invariant_Kept;

   procedure Written_Part (Ctx : in out Context) with SPARK_Mode is
   begin
      Ctx.P.Count := 5;
      pragma Assert (Ctx.P.Count = 5);
      pragma Assert (Free (Ctx.P.Slots));
      pragma Assert (Ctx.P.Count = 0);
   end Written_Part;

   procedure Whole_Written (Ctx : in out Context) with SPARK_Mode is
   begin
      Reset (Ctx);
      pragma Assert (Ctx.P.Count + 0 = 0);
   end Whole_Written;

   procedure Part_Given (Ctx : in out Context) with SPARK_Mode is
   begin
      Bump (Ctx.P.Count);
      pragma Assert (Ctx.P.Slots.S2 = null);
      pragma Assert (0 = Ctx.P.Count);
   end Part_Given;

   procedure Stale_Invariant (Ctx : in out Context) with SPARK_Mode is
   begin
      Ctx.P.Next := 1;
      for I in 1 .. 3 loop
         pragma Loop_Invariant (Ctx.P.Count = 0);
         pragma Loop_Invariant (Ctx.P.Next = 1);
         Ctx.P.Next := I;
      end loop;
   end Stale_Invariant;

   procedure Changing_Function with SPARK_Mode is
      X : Integer := 1;
      function Positive_X return Boolean is (X > 0);
   begin
      pragma Assert (Positive_X);
      X := -1;
      pragma Assert (not Positive_X);
      pragma Assert (not (not Positive_X));
   end Changing_Function;

   function Noisy return Boolean is
   begin
      Calls := Calls + 1;
      return True;
   end Noisy;

   procedure Effectful_Guard is
   begin
      Calls := 0;
      if Noisy then
         pragma Assert (Calls = 0);
         null;
      end if;
   end Effectful_Guard;

   procedure Two_Names (R1, R2 : in out Shared_Rec; Sink : out Integer) is
   begin
      R1.X := 5;
      R2.X := 0;
      Sink := 10 / R1.X;
   end Two_Names;

   procedure Global_Name (R : in out Shared_Rec; Sink : out Integer) is
   begin
      R.Y := 5;
      G_Shared.Y := 0;
      Sink := 10 / R.Y;
   end Global_Name;

end Verification_Part_Frames;
