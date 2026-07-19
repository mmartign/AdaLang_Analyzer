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

   --  An unchanged dynamic index identifies the same component.
   Arr (Index) := 20;
   Arr (Index) := 30;
   Ada.Text_IO.Put_Line (Integer'Image (Arr (Index)));

   --  Once the index changes, equal destination text no longer proves that
   --  the two assignments designate the same component.
   Index := 2;
   Arr (Index) := 40;
   Index := 1;
   Arr (Index) := 50;
   Ada.Text_IO.Put_Line (Integer'Image (Arr (Index)));
end Data_Flow_Precision_Findings;
