package body Verification_Translation_Pieces with SPARK_Mode is

   procedure Ok_Distance (A, B : Idx; D : out Len) is
   begin
      D := A - B;
      pragma Assert (D = Len (A) - Len (B));
   end Ok_Distance;

   procedure Ok_Context (A, B : Idx; D : out Len) is
   begin
      --  Two functions take Idx'Last and 1; the other operand of "<="
      --  is a Len, which settles which.
      pragma Assert (A - B <= Idx'Last - 1);
      D := A - B;
   end Ok_Context;

   procedure Bad_Distance (A, B : Idx; D : out Len) is
   begin
      D := A - B;
      pragma Assert (D = Len (A) - Len (B) + 1);
   end Bad_Distance;

   procedure Ok_Pos (C : Color; P : out Natural) is
   begin
      P := Color'Pos (C);
   end Ok_Pos;

   procedure Bad_Pos (C : Color; P : out Natural) is
   begin
      P := Color'Pos (C);
   end Bad_Pos;

   procedure Ok_Val (N : Natural; C : out Color) is
   begin
      C := Color'Val (N);
   end Ok_Val;

   procedure Reset (X : in out Ctx) is
   begin
      X := (Size => 0, Value => 0);
   end Reset;

   procedure Ok_Plain (O : in out Outer) is
   begin
      Reset (O.Inner.Plain);
   end Ok_Plain;

   procedure Ok_Same (H : in out Holder) is
   begin
      Reset (H.Same);
   end Ok_Same;

   procedure Bad_Fixed (H : in out Holder) is
   begin
      Reset (H.Fixed);
   end Bad_Fixed;

   procedure Bad_Named (H : in out Holder) is
   begin
      Reset (H.Named);
   end Bad_Named;

   procedure Bad_Aliased (H : in out Holder) is
   begin
      Reset (H.Aliased_Part);
   end Bad_Aliased;

   function Ok_Half (X : Natural) return Natural is
   begin
      return X / 2;
   end Ok_Half;

   function Bad_Next (X : Small) return Integer is
   begin
      return X + 1;
   end Bad_Next;

   function Bad_Split (X : Integer) return Integer is
   begin
      if X > 0 then
         return 1;
      end if;
      return 2;
   end Bad_Split;

   procedure Ok_Mask (Y : Unsigned_32; R : out Byte_Range) is
   begin
      R := Y and 16#FF#;
   end Ok_Mask;

   procedure Bad_Mask (Y : Unsigned_32; R : out Byte_Range) is
   begin
      R := Y and 16#1F0#;
   end Bad_Mask;

   procedure Bad_Masked_Claim (Y : Unsigned_32; R : out Unsigned_32) is
   begin
      R := Y and 255;
   end Bad_Masked_Claim;

   procedure Ok_Power (Y : Unsigned_32; R : out Unsigned_32) is
   begin
      R := Y / 2 ** 8;
   end Ok_Power;

   procedure Ok_Right (Y : Unsigned_32; R : out Byte_Range) is
   begin
      R := Shift_Right (Y, 24);
   end Ok_Right;

   procedure Bad_Right (Y : Unsigned_32; R : out Byte_Range) is
   begin
      R := Shift_Right (Y, 16);
   end Bad_Right;

   procedure Ok_Left (Y : Unsigned_8; R : out Unsigned_8) is
   begin
      R := Shift_Left (Y, 1);
   end Ok_Left;

   procedure Bad_Left (Y : Unsigned_8; R : out Unsigned_8) is
   begin
      R := Shift_Left (Y, 1);
   end Bad_Left;

end Verification_Translation_Pieces;
