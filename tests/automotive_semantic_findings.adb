with Ada.Finalization;

procedure Automotive_Semantic_Findings is
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

   type Managed is new Ada.Finalization.Controlled with null record;

   procedure Fail is
   begin
      raise Program_Error;
   end Fail;

   procedure Propagate is
   begin
      Fail;
   end Propagate;

   Item : Child;
   View : Root'Class := Item;
   Resource : Managed;
   pragma Unreferenced (Resource);
begin
   Operate (View);
   Propagate;
end Automotive_Semantic_Findings;
