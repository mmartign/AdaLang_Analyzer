procedure Runtime_Check_Clean (Input : Integer) is
   subtype Small is Integer range 1 .. 10;
   type Vector is array (1 .. 3) of Integer;

   X : Small := 1;
   I : Integer := Input;
   A : Vector := (others => 0);
begin
   pragma Assume (I >= 1 and then I <= 3);
   X := Small (I);
   X := X + 1;
   I := A (I);
end Runtime_Check_Clean;
