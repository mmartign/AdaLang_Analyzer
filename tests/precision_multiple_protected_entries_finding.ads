package Precision_Multiple_Protected_Entries_Finding is
   protected type Buffer is
      entry Put (X : in Integer);
      entry Get (X : out Integer);
   private
      Value : Integer := 0;
      Full  : Boolean := False;
   end Buffer;
end Precision_Multiple_Protected_Entries_Finding;
