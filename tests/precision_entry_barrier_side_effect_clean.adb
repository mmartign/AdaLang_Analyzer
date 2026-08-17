package Precision_Entry_Barrier_Side_Effect_Clean is
   protected Buffer is
      entry Get (X : out Integer);
   private
      Has_Item : Boolean := False;
      Data     : Integer := 0;
   end Buffer;
end Precision_Entry_Barrier_Side_Effect_Clean;

package body Precision_Entry_Barrier_Side_Effect_Clean is
   protected body Buffer is
      entry Get (X : out Integer) when Has_Item is
      begin
         X := Data;
         Has_Item := False;
      end Get;
   end Buffer;
end Precision_Entry_Barrier_Side_Effect_Clean;
