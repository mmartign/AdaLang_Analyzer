procedure Runtime_Check_Findings is
   subtype Small is Integer range 1 .. 10;
   type Vector is array (1 .. 3) of Integer;

   X : Small := 11;
   Y : Integer := 11;
   I : Integer := 4;
   A : Vector := (others => 0);
begin
   X := Y;
   X := Small (0);

   Y := A (4);
   I := 0;
   Y := A (I);
end Runtime_Check_Findings;
