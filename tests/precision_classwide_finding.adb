procedure Precision_Classwide_Finding is
   type Root is tagged null record;
   type Child is new Root with null record;

   Item : Child;
   View : Root'Class := Item;
begin
   null;
end Precision_Classwide_Finding;
