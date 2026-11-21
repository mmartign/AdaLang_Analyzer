--  Use_After_Free: what follows a Free on no path is not a use after it.
--  A handler that frees and raises again does not reach the statements
--  after its block (utilada's Util.Measures, simple_components' SMTP
--  client); a Free in one branch does not reach the other, and a new
--  iteration declares the object anew (simple_components' B-trees and
--  ELV MAX! topology).

with Ada.Unchecked_Deallocation;

procedure Precision_Use_After_Free_Paths_Clean
  (Count : Natural; Fail : Boolean)
is
   type Node;
   type Ptr is access Node;
   type Node is record
      Id   : Integer := 0;
      Next : Ptr;
   end record;
   procedure Free is new Ada.Unchecked_Deallocation (Node, Ptr);
   List : Ptr;
   Keep : Ptr;
begin
   declare
      Item : Ptr := new Node;
   begin
      begin
         if Fail then
            raise Constraint_Error;
         end if;
      exception
         when others =>
            Free (Item);
            raise;
      end;
      Item.Id := 1;
      Keep := Item;
   end;
   for I in 1 .. Count loop
      declare
         Item : Ptr := new Node'(Id => I, Next => null);
      begin
         if I mod 2 = 0 then
            Free (Item);
         else
            Item.Next := List;
            List := Item;
         end if;
      end;
   end loop;
   Keep.Next := List;
end Precision_Use_After_Free_Paths_Clean;
