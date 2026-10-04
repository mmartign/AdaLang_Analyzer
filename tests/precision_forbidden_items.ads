with Ada.Text_IO;

package Precision_Forbidden_Items is
   type Small is range 0 .. 15 with Size => 8;
   Width : constant Integer := Small'Size;
   Counter : Integer := 0;
   procedure Show renames Ada.Text_IO.New_Line;
end Precision_Forbidden_Items;
