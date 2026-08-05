procedure Precision_Dispatching_Call_Clean is
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
begin
   Operate (Item);
end Precision_Dispatching_Call_Clean;
