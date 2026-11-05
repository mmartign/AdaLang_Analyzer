--  Arrays of records in the verification conditions: each component of the
--  elements has contents of its own, read and written at any index,
--  compared component by component, kept through calls, 'Update and
--  loops. Every contract below holds and is proved.
package Verification_Array_Records with SPARK_Mode is
   type Field is (F_A, F_B, F_C, F_D);
   type State is (S_Valid, S_Well_Formed, S_Invalid);
   type Cursor is record
      St    : State := S_Invalid;
      First : Integer := 0;
      Last  : Integer := 0;
   end record;
   type Cursors is array (Field) of Cursor;
   type Values is array (Field) of Integer;
   type Ctx_T is record
      Len  : Integer := 0;
      B    : Integer := 0;
      A    : Values := (others => 0);
      Cur  : Cursors := (others => <>);
      Cur2 : Cursors := (others => <>);
   end record;

   procedure Known_Write (C : in out Cursors) with
     Pre  => C (F_A).St = S_Valid,
     Post => C (F_A).St = S_Valid and C (F_B).St = S_Well_Formed;
   procedure Known_Write_Ctx (X : in out Ctx_T) with
     Pre  => X.Cur (F_A).St = S_Valid and X.Cur (F_A).First = 3,
     Post => X.Cur (F_A).St = S_Valid and X.Cur (F_A).First = 3 and X.Cur (F_C).St = S_Well_Formed and X.Cur (F_C).Last = 7;
   procedure Other_Array (X : in out Ctx_T) with
     Pre  => X.Cur2 (F_A).St = S_Valid,
     Post => X.Cur2 (F_A).St = S_Valid and X.Cur (F_A).First = 0;
   procedure Unknown_Write (X : in out Ctx_T; F : Field) with
     Pre  => F > F_A and X.Cur (F_A).St = S_Valid,
     Post => X.Cur (F_A).St = S_Valid and X.Cur (F).St = S_Invalid;

   procedure Reset (X : in out Ctx_T; Fld : Field);
   procedure Frame (X : in out Ctx_T; Fld : Field) with
     Post => (for all F in Field => (if F < Fld then X.Cur (F) = X.Cur'Old (F) and X.A (F) = X.A'Old (F)));
   procedure Use_Frame (X : in out Ctx_T) with
     Pre  => X.Cur (F_A).St = S_Valid and X.Cur (F_B).Last = 4 and X.A (F_B) = 7,
     Post => X.Cur (F_A).St = S_Valid and X.Cur (F_B).Last = 4 and X.A (F_B) = 7;

   procedure Upd (X : in out Ctx_T) with
     Pre  => X.Cur (F_A).St = S_Valid,
     Post => X.Cur (F_A).St = S_Valid and X.Len = 5;
   procedure Swap (X : in out Ctx_T) with
     Post => X.Len = X.B'Old and X.B = X.Len'Old;

   --  In SPARK two formals are two objects (SPARK RM 6.4.2): a write to an
   --  element of the one leaves the other as it was.
   procedure Other_Formal (First, Second : in out Ctx_T) with
     Pre  => First.Cur (F_A).St = S_Valid,
     Post => First.Cur (F_A).St = S_Valid and Second.Cur (F_A).St = S_Invalid;

   function Is_Valid (X : Ctx_T; F : Field) return Boolean is
     (X.Cur (F).St = S_Valid);
   procedure Need_Valid (X : Ctx_T; F : Field) with
     Pre => Is_Valid (X, F);
   procedure Call_Need (X : in out Ctx_T; F : Field) with
     Pre => X.Cur (F).St = S_Valid;
end Verification_Array_Records;
