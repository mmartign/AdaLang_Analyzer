--  The aspects of a nested subprogram declaration are not evaluated where
--  it is declared: P in the precondition of Pop and A, B in the Global
--  aspect of Load are not read there (qoi, libkeccak, FP-170).
procedure Precision_Uninitialized_Read_Nested_Aspect_Clean
  (Data : String; Sum : out Natural)
is
   P    : Positive;
   A, B : Natural;

   procedure Pop (Result : out Character) with
     Pre  => P in Data'Range,
     Post => P = P'Old + 1;

   procedure Load with
     Global => (Output => (A, B));

   procedure Pop (Result : out Character) is
   begin
      Result := Data (P);
      P := P + 1;
   end Pop;

   procedure Load is
   begin
      A := 1;
      B := 2;
   end Load;

   C : Character;
begin
   Load;
   P := Data'First;
   Pop (C);
   Sum := A + B + Character'Pos (C);
end Precision_Uninitialized_Read_Nested_Aspect_Clean;
