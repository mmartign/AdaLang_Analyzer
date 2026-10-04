package Precision_Multiple_Protected_Entries_Clean is
   protected type Buffer is
      entry Get (X : out Integer);
      procedure Put (X : in Integer);
   private
      Value : Integer := 0;
      Full  : Boolean := False;
   end Buffer;
end Precision_Multiple_Protected_Entries_Clean;
