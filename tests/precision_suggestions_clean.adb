procedure Precision_Suggestions_Clean (Flag : in Boolean; Code : in Integer) is
   type Colour is (Red, Green, Blue);
   type Table is array (1 .. 4) of Integer;
   type Point is record
      X : Integer;
      Y : Integer;
   end record;

   A     : Table := (others => 0);
   P     : Point := (X => 0, Y => 0);
   Total : Integer := 0;
   I     : Integer := 1;
begin
   while Total < 3 loop
      Total := Total + 1;
   end loop;

   loop
      Total := Total + 1;
      exit when Total > 10;
   end loop;

   while I <= 4 loop
      Total := Total + A (I);
      I := I + 2;
   end loop;

   for C in Colour loop
      Total := Total + 1;
   end loop;

   if Code in 1 | 2 | 5 then
      Total := 0;
   end if;

   if Flag then
      Total := 1;
   else
      P.X := 2;
   end if;

   if Code = 1 then
      Total := 1;
   elsif Flag then
      Total := 2;
   end if;

   P.X := Total;
   Total := Total + I;

   for Item of A loop
      Total := Total + Item;
   end loop;

   for J in A'Range loop
      Total := Total + J;
   end loop;
end Precision_Suggestions_Clean;
