procedure Precision_Suggestions (Flag : in Boolean; Code : in Integer) is
   type Colour is (Red, Green, Blue);
   type Table is array (1 .. 4) of Integer;
   type Point is record
      X : Integer;
      Y : Integer;
   end record;

   A, B   : Table := (others => 0);
   P      : Point;
   Total  : Integer := 0;
   Result : Integer := 0;

   function Pick return Integer is
   begin
      if Flag then
         return 1;
      else
         return 2;
      end if;
   end Pick;

   procedure Count_Up is
      I : Integer := 1;
   begin
      while I <= 4 loop
         Total := Total + A (I);
         I := I + 1;
      end loop;
   end Count_Up;
begin
   while True loop
      Total := Total + 1;
      exit when Total > 3;
   end loop;

   loop
      exit when Total > 10;
      Total := Total + 1;
   end loop;

   for C in Colour'First .. Colour'Last loop
      Total := Total + 1;
   end loop;

   for C in Colour'Range loop
      Total := Total + 1;
   end loop;

   if Code = 1 or Code = 2 or Code = 5 then
      Total := 0;
   end if;

   if Code >= 1 and Code <= 5 then
      Total := 1;
   end if;

   if Flag then
      Result := 1;
   else
      Result := 2;
   end if;

   if Code = 1 then
      Total := 1;
   elsif Code = 2 then
      Total := 2;
   elsif Code = 3 then
      Total := 3;
   end if;

   P.X := 1;
   P.Y := 2;

   for I in A'Range loop
      Total := Total + A (I);
   end loop;

   for I in A'Range loop
      A (I) := B (I);
   end loop;

   for I in 1 .. 4 loop
      A (I) := 0;
   end loop;

   Count_Up;
   Total := Total + Pick + Result + P.X;
end Precision_Suggestions;
