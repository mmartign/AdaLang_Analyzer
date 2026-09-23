procedure Precision_Dead_Store_Access_Dereference_Clean
  (Buffer : not null access String)
is
   type String_Access is access all String;
   View : String_Access;
begin
   View := String_Access (Buffer);
   View (1) := 'X';
end Precision_Dead_Store_Access_Dereference_Clean;
