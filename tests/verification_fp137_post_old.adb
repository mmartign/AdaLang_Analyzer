package body Verification_FP137_Post_Old
  with SPARK_Mode
is
   procedure Bad_Division (Divisor : in out Integer) is
   begin
      Divisor := Divisor - 1;
   end Bad_Division;

   procedure Bad_Overflow (Sum : in out Integer) is
   begin
      Sum := Integer'Last;
   end Bad_Overflow;

   procedure Bad_Index (Slot : in out Integer) is
   begin
      Slot := Slot + 1;
   end Bad_Index;

   procedure Bad_Range (Count : in out Integer) is
   begin
      Count := Count - 1;
   end Bad_Range;

   procedure Bad_Element (Element_Ctx : in out Context; V : Integer) is
   begin
      Element_Ctx.C (1) := V;
   end Bad_Element;

   procedure Bad_Whole (Whole_Ctx : in out Context; V : Cells) is
   begin
      Whole_Ctx.C := V;
   end Bad_Whole;

   procedure Bad_Update (Update_Ctx : in out Context; V : Cells) is
   begin
      Update_Ctx := Update_Ctx'Update (C => V);
   end Bad_Update;

   procedure Good_Division (Kept_Divisor : in out Integer) is
   begin
      null;
   end Good_Division;

   procedure Good_Index (Kept_Slot : in out Integer) is
   begin
      null;
   end Good_Index;

   procedure Good_Call (Kept_Ctx : in out Context) is
   begin
      null;
   end Good_Call;

   procedure Good_Indexed (Indexed_Ctx : in out Context) is
   begin
      null;
   end Good_Indexed;
end Verification_FP137_Post_Old;
