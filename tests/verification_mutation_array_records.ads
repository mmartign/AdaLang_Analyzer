--  Seeded defects for arrays of records in the verification conditions:
--  each contract below is false, and must never be proved.
package Verification_Mutation_Array_Records with SPARK_Mode is
   type Field is (F_A, F_B, F_C, F_D);
   type State is (S_Valid, S_Well_Formed, S_Invalid);
   type Cursor is record
      St    : State := S_Invalid;
      First : Integer := 0;
      Last  : Integer := 0;
   end record;
   type Cursors is array (Field) of Cursor;
   type Ctx_T is record
      Len  : Integer := 0;
      B    : Integer := 0;
      Cur  : Cursors := (others => <>);
      Cur2 : Cursors := (others => <>);
   end record;

   procedure Written_Known (C : in out Cursors) with
     Pre => C (F_B).St = S_Valid, Post => C (F_B).St = S_Valid;
   procedure Written_Unknown (X : in out Ctx_T; F : Field) with
     Pre => X.Cur (F_A).St = S_Valid, Post => X.Cur (F_A).St = S_Valid;
   procedure Written_Component (X : in out Ctx_T; F : Field) with
     Pre => X.Cur (F_A).First = 3, Post => X.Cur (F_A).First = 3;
   procedure Same_Index (X : in out Ctx_T; F, G : Field) with
     Pre => X.Cur (G).St = S_Valid, Post => X.Cur (G).St = S_Valid;
   procedure Element_Changed (X : in out Ctx_T) with
     Pre => X.Cur (F_A).First = 3, Post => X.Cur (F_A) = X.Cur'Old (F_A);
   procedure Need_Equal (A, B : Cursor) with Pre => A = B;
   procedure One_Component_Equal (C : Cursors) with
     Pre => C (F_A).St = C (F_B).St and C (F_A).First /= C (F_B).First;
   procedure Default_First (C : in out Cursors) with
     Post => C (F_A).First = 1;
   procedure Read_Known_After (C : in out Cursors; F : Field) with
     Pre => C (F_C).Last = 9, Post => C (F_C).Last = 9;
   procedure Through_Renaming (X : in out Ctx_T) with
     Pre => X.Cur (F_A).Last = 4, Post => X.Cur (F_A).Last = 4;
   procedure Old_Of_Written (X : in out Ctx_T; F : Field) with
     Post => X.Cur (F).St = X.Cur'Old (F).St;

   procedure Reset (X : in out Ctx_T; Fld : Field) with
     Post => (for all F in Field => (if F < Fld then X.Cur (F) = X.Cur'Old (F)));
   procedure Frame_Empty (X : in out Ctx_T) with
     Pre => X.Cur (F_A).First = 5, Post => X.Cur (F_A).First = 5;
   procedure Frame_Edge (X : in out Ctx_T) with
     Pre => X.Cur (F_B).First = 5, Post => X.Cur (F_B).First = 5;
   procedure Frame_Unknown (X : in out Ctx_T; G : Field) with
     Pre => X.Cur (F_B).Last = 5, Post => X.Cur (F_B).Last = 5;

   procedure Updated (X : in out Ctx_T) with
     Pre => X.Len = 3, Post => X.Len = 3;
   procedure Updated_Array (X : in out Ctx_T; O : Cursors) with
     Pre => X.Cur (F_A).Last = 3, Post => X.Cur (F_A).Last = 3;
   procedure Updated_Other (X : in out Ctx_T; Y : Ctx_T) with
     Pre => X.B = 1 and Y.B = 2, Post => X.B = 1;
   procedure Swapped (X : in out Ctx_T) with
     Pre => X.Len /= X.B, Post => X.Len = X.Len'Old;

   procedure Loop_Writes_All (X : in out Ctx_T) with
     Pre => X.Cur (F_D).St = S_Valid, Post => X.Cur (F_D).St = S_Valid;
end Verification_Mutation_Array_Records;
