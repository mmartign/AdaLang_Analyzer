--  FP-144 boundary: Width belongs to the enclosing procedure and Show,
--  declared there, reads it; but between Emit's two assignments only
--  Ada.Strings.Unbounded's Append is called, which runs no body declared
--  in the enclosing procedure, so the first value is overwritten before
--  any read and must be flagged (GNATCOLL gnatcoll-email-utils.adb).
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

procedure Precision_Overwritten_Assignment_Up_Level_Outside_Call_Finding
  (Text : String; Result : out Unbounded_String)
is
   Width : Natural := 0;

   procedure Show is
   begin
      Append (Result, Natural'Image (Width));
   end Show;

   procedure Emit (Item : String) is
   begin
      Width := 0;
      Append (Result, "<");
      Append (Result, Item);
      Width := Item'Length;
      Show;
   end Emit;
begin
   Result := Null_Unbounded_String;
   Emit (Text);
end Precision_Overwritten_Assignment_Up_Level_Outside_Call_Finding;
