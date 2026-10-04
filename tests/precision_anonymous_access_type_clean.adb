procedure Precision_Anonymous_Access_Type_Clean is
   type Integer_Ref is access all Integer;
   Value : aliased Integer := 0;
   Ref   : constant Integer_Ref := Value'Access;

   procedure Bump (Item : access Integer) is
   begin
      Item.all := Item.all + 1;
   end Bump;
begin
   Bump (Ref);
end Precision_Anonymous_Access_Type_Clean;
