package body Verification_Parts_Kept
  with SPARK_Mode
is
   procedure Element_Through_Pointer (Ctx : in out Context) is
   begin
      Ctx.Buffer (1) := 0;
      pragma Assert (Ctx.First = 3);
      pragma Assert (Ctx.Cursor (F_B).State = 7);
   end Element_Through_Pointer;

   procedure Slice_Through_Pointer (Ctx : in out Context; Data : Bytes) is
   begin
      Ctx.Buffer.all (1 .. 2) := Data;
      pragma Assert (Ctx.Cursor (F_B).State = 7);
   end Slice_Through_Pointer;

   procedure Fill (Data : out Bytes) is
   begin
      Data := (others => 0);
   end Fill;

   procedure Call_Through_Pointer (Ctx : in out Context) is
   begin
      Fill (Ctx.Buffer.all);
      pragma Assert (Ctx.Cursor (F_B).State = 7);
   end Call_Through_Pointer;

   function Needs_B (F : Field) return Integer is (Field'Pos (F));
   function Needs_Late (F : Field) return Integer is (Field'Pos (F));
   function Needs_Small (N : Integer) return Integer is (N);
   function Needs_Other (N : Integer) return Integer is (0);

   procedure Added (I : Index; N : Length; R : out Index) is
   begin
      R := I + N;
   end Added;

   procedure Taken (I, J : Index; R : out Length) is
   begin
      R := I - J;
   end Taken;

   procedure Negated (N : Length; R : out Length) is
   begin
      R := -N;
   end Negated;

   procedure Copied_Declaration (H : Holder) is
      Tmp : constant Pair := H.P;
   begin
      pragma Assert (Tmp.X = 1);
   end Copied_Declaration;

   procedure Copied_Back (H : in out Holder) is
      Tmp : Pair := H.P;
   begin
      H.P := (X => 0, Y => 0);
      H.Q := Tmp;
      H.P := Tmp;
      pragma Assert (Tmp.X = 1);
   end Copied_Back;

   function Ready (Cursor : Slots) return Natural is
     (Cursor (F_B).Size);

   function Ready_Of (Ctx : Context) return Natural is
     (Ready (Ctx.Cursor));

   procedure Log (Text : String) is
   begin
      null;
   end Log;

   procedure Slice_Given (S : String) is
   begin
      Log (S (2 .. 5));
   end Slice_Given;

   procedure Log_Nothing (Text : String) is
   begin
      null;
   end Log_Nothing;

   procedure Empty_Given (S : String) is
   begin
      Log_Nothing (S (1 .. 0));
   end Empty_Given;
end Verification_Parts_Kept;
