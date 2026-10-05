procedure Precision_Integer_Type_As_Enumeration is
   type Enum is range 1 .. 3;
   type Int is range 1 .. 3;
   type Flags is mod 8;
   type Parent is range 1 .. 9;
   type Child is new Parent;
   type Base is range 1 .. 9;
   subtype Small is Base range 1 .. 3;
   type Source is range 1 .. 9;
   type Target is range 1 .. 9;
   type Tag is mod 4;

   X : Enum := 1;
   Y : Int := 1;
   F : Flags := 1;
   C : Child := 1;
   S : Small := 1;
   A : Source := 2;
   B : Target := 2;
   T : Tag := 0;
begin
   X := 2;
   Y := Y + 1;
   F := F and 3;
   B := Target (A);
   if X = 2 and then C = 1 and then S = 1 and then T = 0 then
      null;
   end if;
end Precision_Integer_Type_As_Enumeration;
