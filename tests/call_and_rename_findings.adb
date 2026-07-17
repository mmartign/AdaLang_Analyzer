with Ada.Text_IO;

--  Regression fixture for object renames, call-site outputs, and the explicit
--  dereference boundary of the data-flow checks.
procedure Call_And_Rename_Findings is
   procedure Fill (Value : out Integer) is
   begin
      Value := 1;
   end Fill;

   X    : Integer := 0;
   Y    : Integer;
   View : Integer renames X;

   type Int_Access is access all Integer;
   Target  : aliased Integer := 0;
   Pointer : Int_Access := Target'Access;
begin
   View := X;
   Ada.Text_IO.Put_Line (Integer'Image (X));

   Fill (X);
   Ada.Text_IO.Put_Line (Integer'Image (X));

   Fill (Y);

   --  Explicit dereference destinations are outside the conservative target
   --  model: without points-to analysis even two different access values can
   --  designate the same storage.
   Pointer.all := 10;
end Call_And_Rename_Findings;
