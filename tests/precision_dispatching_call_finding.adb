procedure Precision_Dispatching_Call_Finding is
   package Hierarchy is
      type Root is tagged null record;
      procedure Operate (Value : in out Root);

      type Child is new Root with null record;
      overriding procedure Operate (Value : in out Child);
   end Hierarchy;

   package body Hierarchy is
      procedure Operate (Value : in out Root) is
      begin
         null;
      end Operate;

      overriding procedure Operate (Value : in out Child) is
      begin
         null;
      end Operate;
   end Hierarchy;

   use Hierarchy;

   Item : Child;
   View : Root'Class := Item;
begin
   Operate (View);
end Precision_Dispatching_Call_Finding;
