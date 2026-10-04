procedure Precision_Lowercase_Keyword_Clean is
   type Small is range 0 .. 9;
   Width : constant Integer := Small'Size;
   First : constant Small := Small'First;
   type Ref is access all Integer;
   Value : aliased Integer := Width;
   R : constant Ref := Value'Access;
begin
   R.all := Integer (First);
end Precision_Lowercase_Keyword_Clean;
