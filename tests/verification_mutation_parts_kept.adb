package body Verification_Mutation_Parts_Kept
  with SPARK_Mode
is
   --  The element written is not what it was.
   procedure Written_Element (Ctx : in out Context; Value : Byte) is
   begin
      if Ctx.Buffer (1) = 0 then
         Ctx.Buffer (1) := Value;
         pragma Assert (Ctx.Buffer (1) = 0);
      end if;
   end Written_Element;

   procedure Written_Slice (Ctx : in out Context; Data : Bytes) is
   begin
      if Ctx.Buffer (2) = 0 then
         Ctx.Buffer.all (1 .. 2) := Data;
         pragma Assert (Ctx.Buffer (2) = 0);
      end if;
   end Written_Slice;

   --  A function of the record reads through the access value it holds.
   procedure Read_By_Function (Ctx : in out Context; Value : Byte) is
   begin
      if First_Byte (Ctx) = 0 then
         Ctx.Buffer (1) := Value;
         pragma Assert (First_Byte (Ctx) = 0);
      end if;
   end Read_By_Function;

   --  A function of the access value, which itself does not change.
   procedure Read_By_Pointer (Ctx : in out Context; Value : Byte) is
   begin
      if Head (Ctx.Buffer) = 0 then
         Ctx.Buffer (1) := Value;
         pragma Assert (Head (Ctx.Buffer) = 0);
      end if;
   end Read_By_Pointer;

   procedure Fill (Data : out Bytes) is
   begin
      Data := (others => 1);
   end Fill;

   procedure Written_By_Call (Ctx : in out Context) is
   begin
      if Ctx.Buffer (1) = 0 then
         Fill (Ctx.Buffer.all);
         pragma Assert (Ctx.Buffer (1) = 0);
      end if;
   end Written_By_Call;

   --  An element of a named array is written, unlike what is designated.
   procedure Named_Element_Written (Ctx : in out Context; State : Integer) is
   begin
      if Ctx.Cursor (F_B).State = 0 then
         Ctx.Cursor (F_B).State := State;
         pragma Assert (Ctx.Cursor (F_B).State = 0);
      end if;
   end Named_Element_Written;

   function Needs_B (F : Field) return Integer is (Field'Pos (F));
   function Needs_Late (F : Field) return Integer is (Field'Pos (F));
   function Needs_Small (N : Integer) return Integer is (N);
   function Needs_Big (N : Integer) return Integer is (N);

   --  The sum can be past the last index.
   procedure Too_Much (I : Index; N : Length; R : out Index) is
   begin
      R := I + N;
   end Too_Much;

   --  The operands the other way round: I >= J says nothing of J >= I.
   procedure Swapped (I, J : Index; R : out Length) is
   begin
      R := J - I;
   end Swapped;

   procedure Negated_Zero (N : Length; R : out Length) is
   begin
      R := -N;
   end Negated_Zero;

   function Sum (P : Pair) return Integer is (P.X + P.Y);

   --  The copy keeps the old value and the source does not.
   procedure Source_Written (H : in out Holder; V : Integer) is
      Tmp : constant Pair := H.P;
   begin
      H.P.X := V;
      pragma Assert (Tmp.X = V);
   end Source_Written;

   procedure Source_Forgets (H : in out Holder; V : Integer) is
      Tmp : constant Pair := H.P;
   begin
      H.P.X := V;
      pragma Assert (H.P.X = Tmp.X);
   end Source_Forgets;

   --  The source keeps the old value and the copy does not.
   procedure Target_Written (H : in out Holder; V : Integer) is
      Tmp : Pair := H.P;
   begin
      Tmp.X := V;
      pragma Assert (H.P.X = V);
   end Target_Written;

   procedure Target_Forgets (H : in out Holder; V : Integer) is
      Tmp : Pair := H.P;
   begin
      Tmp.X := V;
      pragma Assert (Tmp.X = H.P.X);
   end Target_Forgets;

   --  Nothing was said of the other component, nor of the other part.
   procedure Other_Component (H : in out Holder) is
      Tmp : constant Pair := H.P;
   begin
      pragma Assert (Tmp.Y = 1);
      pragma Assert (H.Q.X = 1);
   end Other_Component;

   procedure Whole_Then_Written (A : in out Pair) is
      B : Pair;
   begin
      B := A;
      A.X := 3;
      pragma Assert (B.X = 3);
   end Whole_Then_Written;

   --  The copy keeps its value: the function of the two now differs.
   procedure Function_Of_Copy (A : in out Pair) is
      B : constant Pair := A;
   begin
      A.X := 3;
      pragma Assert (Sum (B) = Sum (A));
   end Function_Of_Copy;

   procedure Element_After_Copy (A : in out With_Row) is
      B : constant With_Row := A;
   begin
      A.Data (2) := 9;
      pragma Assert (B.Data (2) = 9);
   end Element_After_Copy;

   --  The component is given another value: the old one is gone.
   procedure Assigned_Over (H : in out Holder; V : Pair) is
   begin
      H.P := V;
      pragma Assert (H.P.X = 1);
   end Assigned_Over;

   procedure Log (Text : String) is
   begin
      null;
   end Log;

   procedure Log_First (Text : String) is
   begin
      null;
   end Log_First;

   procedure Log_Empty (Text : String) is
   begin
      null;
   end Log_Empty;

   procedure Log_Four (Text : Four) is
   begin
      null;
   end Log_Four;

   --  Five characters, not four.
   procedure Wrong_Length (S : String) is
   begin
      Log (S (2 .. 6));
   end Wrong_Length;

   --  The slice starts at 2.
   procedure Wrong_First (S : String) is
   begin
      Log_First (S (2 .. 5));
   end Wrong_First;

   --  An empty slice has no length.
   procedure Empty_Slice (S : String) is
   begin
      Log_Empty (S (1 .. 0));
   end Empty_Slice;

   --  The formal fixes its bounds: the slice slides to them.
   procedure Slid_Slice (S : String) is
   begin
      Log_Four (S (2 .. 5));
   end Slid_Slice;
end Verification_Mutation_Parts_Kept;
