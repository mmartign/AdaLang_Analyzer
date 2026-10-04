procedure Precision_Ada_2022 is
   type Point is record
      X, Y : Integer;
   end record;
   type Table is array (1 .. 3) of Integer;

   P : Point := (X => 1, Y => 2);
   Q : constant Point := (P with delta X => 5);
   T : constant Table := (for I in 1 .. 3 => I * 2);
   Total : Integer := 0;
   Sum : constant Integer := (declare Half : constant Integer := Q.X / 2;
                              begin Half + 1);
   Ghost_Copy : constant Point := (P with delta Y => 0) with Ghost;
begin
   Total := @ + Sum + T (1);
   P.X := Total;
   pragma Assert (Ghost_Copy.Y = 0);
end Precision_Ada_2022;
