package body Verification_Array_Records with SPARK_Mode is
   pragma Warnings (Off, "attribute Update is an obsolescent feature");

   procedure Known_Write (C : in out Cursors) is
   begin
      C (F_B) := (St => S_Well_Formed, First => 1, Last => 2);
   end Known_Write;

   procedure Known_Write_Ctx (X : in out Ctx_T) is
   begin
      X.Cur (F_C) := (St => S_Well_Formed, First => 1, Last => 7);
   end Known_Write_Ctx;

   --  The default of First is 0.
   procedure Other_Array (X : in out Ctx_T) is
   begin
      X.Cur (F_A) := (St => S_Invalid, others => <>);
   end Other_Array;

   procedure Unknown_Write (X : in out Ctx_T; F : Field) is
   begin
      X.Cur (F) := (St => S_Invalid, others => <>);
   end Unknown_Write;

   --  A loop over an enumeration, X.Cur'Loop_Entry and the equality of
   --  elements in its invariant.
   procedure Reset (X : in out Ctx_T; Fld : Field) is
   begin
      for L in reverse Fld .. Field'Last loop
         pragma Loop_Invariant ((for all F in Field => (if F <= L then X.Cur (F) = X.Cur'Loop_Entry (F) else X.Cur (F).St = S_Invalid)));
         pragma Loop_Invariant (X.Len = X.Len'Loop_Entry);
         X.Cur (L) := (St => S_Invalid, others => <>);
      end loop;
   end Reset;

   procedure Frame (X : in out Ctx_T; Fld : Field) is
   begin
      null;
   end Frame;

   procedure Use_Frame (X : in out Ctx_T) is
   begin
      Frame (X, F_C);
   end Use_Frame;

   procedure Upd (X : in out Ctx_T) is
   begin
      X := X'Update (Len => 5);
   end Upd;

   --  Each value is read before any component is given one.
   procedure Swap (X : in out Ctx_T) is
   begin
      X := X'Update (Len => X.B, B => X.Len);
   end Swap;

   procedure Other_Formal (First, Second : in out Ctx_T) is
   begin
      Second.Cur (F_A) := (St => S_Invalid, others => <>);
   end Other_Formal;

   procedure Need_Valid (X : Ctx_T; F : Field) is null;

   procedure Call_Need (X : in out Ctx_T; F : Field) is
   begin
      Need_Valid (X, F);
   end Call_Need;
end Verification_Array_Records;
