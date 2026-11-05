package body Verification_Mutation_Array_Records with SPARK_Mode is
   pragma Warnings (Off, "attribute Update is an obsolescent feature");

   --  The element written is no longer what it was.
   procedure Written_Known (C : in out Cursors) is
   begin
      C (F_B) := (St => S_Invalid, First => 1, Last => 2);
   end Written_Known;

   --  F may be F_A.
   procedure Written_Unknown (X : in out Ctx_T; F : Field) is
   begin
      X.Cur (F) := (St => S_Invalid, others => <>);
   end Written_Unknown;

   procedure Written_Component (X : in out Ctx_T; F : Field) is
   begin
      X.Cur (F) := (St => S_Valid, First => 4, Last => 4);
   end Written_Component;

   --  F may be G.
   procedure Same_Index (X : in out Ctx_T; F, G : Field) is
   begin
      X.Cur (F) := (St => S_Invalid, others => <>);
   end Same_Index;

   procedure Element_Changed (X : in out Ctx_T) is
   begin
      X.Cur (F_A).First := 7;
   end Element_Changed;

   procedure Need_Equal (A, B : Cursor) is null;

   --  Equal in one component, not in another.
   procedure One_Component_Equal (C : Cursors) is
   begin
      Need_Equal (C (F_A), C (F_B));
   end One_Component_Equal;

   --  The default of First is 0.
   procedure Default_First (C : in out Cursors) is
   begin
      C (F_A) := (St => S_Valid, others => <>);
   end Default_First;

   --  F may be F_C.
   procedure Read_Known_After (C : in out Cursors; F : Field) is
   begin
      C (F) := (St => S_Valid, First => 1, Last => 1);
   end Read_Known_After;

   procedure Through_Renaming (X : in out Ctx_T) is
      R : Cursor renames X.Cur (F_A);
   begin
      R := (St => S_Invalid, First => 0, Last => 0);
   end Through_Renaming;

   procedure Old_Of_Written (X : in out Ctx_T; F : Field) is
   begin
      X.Cur (F) := (St => S_Invalid, others => <>);
   end Old_Of_Written;

   procedure Reset (X : in out Ctx_T; Fld : Field) is
   begin
      null;
   end Reset;

   --  The frame keeps nothing below F_A.
   procedure Frame_Empty (X : in out Ctx_T) is
   begin
      Reset (X, F_A);
   end Frame_Empty;

   --  The element at Fld is not in the frame.
   procedure Frame_Edge (X : in out Ctx_T) is
   begin
      Reset (X, F_B);
   end Frame_Edge;

   procedure Frame_Unknown (X : in out Ctx_T; G : Field) is
   begin
      Reset (X, G);
   end Frame_Unknown;

   procedure Updated (X : in out Ctx_T) is
   begin
      X := X'Update (Len => 4);
   end Updated;

   procedure Updated_Array (X : in out Ctx_T; O : Cursors) is
   begin
      X := X'Update (Cur => O);
   end Updated_Array;

   --  X becomes Y with another Len: its B is Y's.
   procedure Updated_Other (X : in out Ctx_T; Y : Ctx_T) is
   begin
      X := Y'Update (Len => 5);
   end Updated_Other;

   procedure Swapped (X : in out Ctx_T) is
   begin
      X := X'Update (Len => X.B, B => X.Len);
   end Swapped;

   --  The loop invalidates every element, F_D included.
   procedure Loop_Writes_All (X : in out Ctx_T) is
   begin
      for L in reverse F_A .. Field'Last loop
         X.Cur (L) := (St => S_Invalid, others => <>);
      end loop;
   end Loop_Writes_All;
end Verification_Mutation_Array_Records;
