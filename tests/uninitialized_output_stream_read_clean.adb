with Ada.Streams.Stream_IO;
procedure Uninitialized_Output_Stream_Read_Clean
  (Strm : Ada.Streams.Stream_IO.Stream_Access;
   Item : out Character) is
begin
   --  The second argument of 'Read is the attribute's out parameter
   --  (RM 13.13.2): Item is written on the only path (FP-123).
   Character'Read (Strm, Item);
end Uninitialized_Output_Stream_Read_Clean;
