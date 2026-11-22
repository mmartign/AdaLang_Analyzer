--  FP-168: an out parameter that a subprogram declared inside the one it
--  belongs to writes, as an up-level object, is written when that one
--  calls it: apdf's Image_ref, whose recursive Insert sets Index, and
--  Excel_Writer's Write_as_Formula, whose nested function, called in a
--  declaration, sets Valid. Neither the caller's read of the actual nor
--  the read of Valid after the declaration is a definite error.

procedure Verification_FP168_Nested_Out_Write
  (Key : String; Total : out Natural)
is
   procedure Ref (Name : String; Index : out Positive) is
      procedure Insert (N : String) is
      begin
         if N'Length > 3 then
            Index := N'Length;
         else
            Index := 1;
         end if;
      end Insert;
   begin
      Insert (Name);
   end Ref;

   procedure Write (S : String; Valid : out Boolean; Len : out Natural) is
      function Tokenize return Natural is
      begin
         Valid := S'Length > 0;
         return S'Length;
      end Tokenize;

      Count : constant Natural := Tokenize;
   begin
      if Valid then
         Len := Count;
      else
         Len := 0;
      end if;
   end Write;

   I  : Positive;
   OK : Boolean;
   N  : Natural;
begin
   Ref (Key, I);
   Write (Key, OK, N);
   if OK then
      Total := N + I mod 2;
   else
      Total := I mod 2;
   end if;
end Verification_FP168_Nested_Out_Write;
