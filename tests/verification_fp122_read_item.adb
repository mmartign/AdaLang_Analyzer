--  FP-122: the second argument of "T'Read (Stream, Item)" is the
--  attribute's out parameter (RM 13.13.2), written by it; it was taken for
--  a read, and of an out parameter not yet assigned that is a definite
--  error. The argument of 'Write is read: Twice, never assigned, is.
with Ada.Streams.Stream_IO;
procedure Verification_FP122_Read_Item
  (Strm  : Ada.Streams.Stream_IO.Stream_Access;
   Item  : out Character;
   Twice : out Character) is
begin
   Character'Read (Strm, Item);
   Character'Write (Strm, Twice);
end Verification_FP122_Read_Item;
