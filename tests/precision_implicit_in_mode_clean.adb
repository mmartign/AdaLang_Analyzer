procedure Precision_Implicit_In_Mode_Clean (X : in Integer) is
   procedure Visit (Item : access Integer; Count : in out Integer) is
   begin
      Count := Count + Item.all;
   end Visit;

   Value : aliased Integer := X;
   Total : Integer := 0;
begin
   Visit (Value'Access, Total);
end Precision_Implicit_In_Mode_Clean;
