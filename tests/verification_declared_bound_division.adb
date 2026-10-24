package body Verification_Declared_Bound_Division
  with SPARK_Mode
is
   procedure Ok_Block (Ctx : Context; X : out Integer) is
   begin
      X := Ctx.Block_Size - 1;
      X := Ctx.Block_Size * 8;
   end Ok_Block;

   procedure Ok_Initial (Ctx : Context; X : out Integer) is
      Initial : constant Positive := Ctx.Block_Size;
   begin
      X := Initial + 1;
   end Ok_Initial;

   procedure Ok_Half (Ctx : Context; X : out Integer) is
   begin
      X := Ctx.H * 2;
   end Ok_Half;

   --  M is in 0 .. 7 and R in -8 .. 0.
   procedure Ok_Digits (Ctx : Context; X : out Integer) is
   begin
      X := Ctx.M + (Integer'Last - 7);
      X := Ctx.R - (Integer'Last - 7);
   end Ok_Digits;

   procedure Bad_Half_Plus (Ctx : Context; X : out Integer) is
   begin
      X := Ctx.HP * 2;
   end Bad_Half_Plus;

   procedure Bad_Last_Digit (Ctx : Context; X : out Integer) is
   begin
      X := Ctx.M + (Integer'Last - 6);
   end Bad_Last_Digit;

   procedure Bad_First_Digit (Ctx : Context; X : out Integer) is
   begin
      X := Ctx.R - (Integer'Last - 6);
   end Bad_First_Digit;
end Verification_Declared_Bound_Division;
