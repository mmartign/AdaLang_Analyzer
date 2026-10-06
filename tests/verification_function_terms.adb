package body Verification_Function_Terms with SPARK_Mode is

   procedure Step (Ctx : in out Context) is
   begin
      Ctx.Used := Ctx.Used + 1;
   end Step;

   procedure Fill (Ctx : in out Context; Need : Natural) is
   begin
      Ctx.Used := Ctx.Used + Need;
   end Fill;

   procedure Fire (Ctx : in out Context) is
   begin
      Ctx.Used := 0;
   end Fire;

   procedure Forward (Whole : in out Context) is
   begin
      Step (Whole);
   end Forward;

   procedure Forward_Both (Both : in out Context; Need : Natural) is
   begin
      Fill (Both, Need);
   end Forward_Both;

   procedure Forward_Named (Named : in out Context; Need : Natural) is
   begin
      Fill (Need => Need, Ctx => Named);
   end Forward_Named;

   procedure Guarded (Kept : in out Context) is
   begin
      Step (Kept);
   end Guarded;

   procedure Twice (Again : in out Context) is
   begin
      Step (Again);
      Step (Ctx => Again);
   end Twice;

   procedure Other_Object (Known, Other : in out Context) is
   begin
      Step (Other);
      Step (Known);
   end Other_Object;

   procedure Other_Argument (Sized : in out Context; Need, More : Natural) is
   begin
      Fill (Sized, More);
   end Other_Argument;

   procedure After_Element (Written : in out Context) is
   begin
      Written.Data (1) := 0;
      Step (Written);
   end After_Element;

   procedure After_Component (Changed : in out Context) is
   begin
      Changed.Used := 8;
      Step (Changed);
   end After_Component;

   procedure After_Assignment (Replaced : in out Context; From : Context) is
   begin
      Replaced := From;
      Step (Replaced);
   end After_Assignment;

   procedure In_Loop (Repeated : in out Context) is
   begin
      for Round in 1 .. 3 loop
         Step (Repeated);
      end loop;
   end In_Loop;

   procedure On_One_Path (Joined : in out Context; Flag : Boolean) is
   begin
      if Flag then
         Joined.Data (2) := 1;
      end if;
      Step (Joined);
   end On_One_Path;

   procedure Unguarded (Loose : in out Context) is
   begin
      Loose.Used := 0;
   end Unguarded;

   procedure With_Global (Aimed : in out Context) is
   begin
      Threshold := Threshold + 1;
      Fire (Aimed);
   end With_Global;

end Verification_Function_Terms;
