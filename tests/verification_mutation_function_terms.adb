package body Verification_Mutation_Function_Terms with SPARK_Mode is

   function Ready (Ctx : Context) return Boolean is
   begin
      return Ctx.Used < 8 and then Ctx.Data (1) < 8 and then Ctx.Data (2) < 8;
   end Ready;

   function Sum_Ok (Ctx : Context) return Boolean is
   begin
      return Ctx.Heap /= null and then Ctx.Heap (1) > 0;
   end Sum_Ok;

   function Below (Ctx : Context; Bound : Natural := 4) return Boolean is
   begin
      return Ctx.Data (1) < Bound;
   end Below;

   function Under_Limit (Ctx : Context) return Boolean is
   begin
      return Ctx.Data (1) < Limit;
   end Under_Limit;

   procedure Step (Ctx : in out Context) is
   begin
      Ctx.Used := Ctx.Used + 1;
   end Step;

   procedure Sum (Ctx : in out Context) is
   begin
      Ctx.Used := 0;
   end Sum;

   procedure Low (Ctx : in out Context) is
   begin
      Ctx.Used := 0;
   end Low;

   procedure Capped (Ctx : in out Context) is
   begin
      Ctx.Used := 0;
   end Capped;

   procedure Element_Written (Written : in out Context) is
   begin
      Written.Data (2) := 9;
      Step (Written);
   end Element_Written;

   procedure Slice_Written (Sliced : in out Context) is
   begin
      Sliced.Data (1 .. 2) := (9, 9);
      Step (Sliced);
   end Slice_Written;

   procedure Component_Written (Changed : in out Context) is
   begin
      Changed.Used := 8;
      Step (Changed);
   end Component_Written;

   procedure Renaming_Written (Renamed : in out Context) is
      View : Cells renames Renamed.Data;
   begin
      View (1) := 9;
      Step (Renamed);
   end Renaming_Written;

   procedure Other_Formal_Written (First, Second : in out Context) is
   begin
      Second.Data (1) := 9;
      Step (First);
   end Other_Formal_Written;

   procedure Heap_Written (Pointing : in out Context) is
   begin
      Shared (1) := 0;
      Sum (Pointing);
   end Heap_Written;

   procedure Written_In_Loop (Looped : in out Context) is
   begin
      for Round in 1 .. 2 loop
         pragma Assume (Ready (Looped));
         Looped.Data (Round) := 9;
      end loop;
      Step (Looped);
   end Written_In_Loop;

   procedure Declared_In_Loop is
   begin
      for Round in 1 .. 3 loop
         declare
            Fresh : Context;
         begin
            if Round = 1 then
               pragma Assume (Ready (Fresh));
            end if;
            Step (Fresh);
         end;
      end loop;
   end Declared_In_Loop;

   procedure Called_Before (Again : in out Context) is
   begin
      Step (Again);
      Step (Ctx => Again);
   end Called_Before;

   procedure Default_Differs (Defaulted : in out Context) is
   begin
      Low (Defaulted);
   end Default_Differs;

   procedure Variable_Read (Capped_Ctx : in out Context) is
   begin
      Limit := 0;
      Capped (Capped_Ctx);
   end Variable_Read;

   package body Loose with SPARK_Mode => Off is
      function Poke (Target : Cells_Access) return Boolean is
      begin
         Target (1) := 0;
         return True;
      end Poke;
   end Loose;

   procedure Poked_Before (Poked : in out Context; Flag : out Boolean) is
   begin
      Flag := Loose.Poke (Poked.Heap);
      Sum (Poked);
   end Poked_Before;

   procedure Poked_In_Condition (Tested : in out Context) is
   begin
      if Loose.Poke (Tested.Heap) then
         Sum (Tested);
      end if;
   end Poked_In_Condition;

   procedure Poked_After_Guard (Guarded : in out Context) is
   begin
      if Sum_Ok (Guarded) and then Loose.Poke (Guarded.Heap) then
         Sum (Guarded);
      end if;
   end Poked_After_Guard;

   package body Bounded with SPARK_Mode is
      function Fits (Ctx : Context) return Boolean is
      begin
         return Ctx.Data (1) < Bound;
      end Fits;

      procedure Use_It (Ctx : in out Context) is
      begin
         Ctx.Data (1) := 0;
      end Use_It;
   end Bounded;

   procedure Other_Instance (Mixed : in out Context) is
   begin
      Small.Use_It (Mixed);
   end Other_Instance;

end Verification_Mutation_Function_Terms;
