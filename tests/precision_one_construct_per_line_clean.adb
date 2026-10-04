with Ada.Text_IO; use Ada.Text_IO;

procedure Precision_One_Construct_Per_Line_Clean (Flag : in Boolean) is
   type Colour is (Red, Green, Blue);
   X : Colour := Red;
begin
   Outer : for I in 1 .. 2 loop
      if Flag then
         X := Green;
      end if;
   end loop Outer;
   Put_Line (Colour'Image (X));
end Precision_One_Construct_Per_Line_Clean;
