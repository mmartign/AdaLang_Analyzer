package Precision_Entry_Barrier_Side_Effect_Finding is
   protected Buffer is
      entry Get (X : out Integer);
   private
      function Has_Item (Count : in out Integer) return Boolean;
      Data : Integer := 0;
   end Buffer;
end Precision_Entry_Barrier_Side_Effect_Finding;

package body Precision_Entry_Barrier_Side_Effect_Finding is
   protected body Buffer is
      entry Get (X : out Integer) when Has_Item (Data) is
      begin
         X := Data;
      end Get;

      function Has_Item (Count : in out Integer) return Boolean is
      begin
         Count := Count - 1;
         return Count >= 0;
      end Has_Item;
   end Buffer;
end Precision_Entry_Barrier_Side_Effect_Finding;
