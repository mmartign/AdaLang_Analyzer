with Ada.Text_IO;

--  Regression fixture for nested reads and statically indexed components.
procedure Data_Flow_Precision_Findings is
   X      : Integer := 0;
   Result : Integer;
   Temp   : Integer;
   Arr    : array (1 .. 3) of Integer := (others => 0);
   Index  : Integer := 1;
begin
   X := 1;
   Ada.Text_IO.Put_Line (Integer'Image (X));

   Result := 100 / X;
   Ada.Text_IO.Put_Line (Integer'Image (Result));

   Temp := X * X;

   Arr (1) := 5;
   Arr (1) := 10;
   Arr (2) := 5;
   Arr (3) := Arr (1);
   Ada.Text_IO.Put_Line (Integer'Image (Arr (3)));

   --  Dynamic indices are intentionally not equated: Index could change or
   --  alias another expression between writes.
   Arr (Index) := 20;
   Index := 2;
   Arr (Index) := 30;
end Data_Flow_Precision_Findings;
