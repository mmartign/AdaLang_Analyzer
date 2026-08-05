procedure Precision_Implicit_Deref_Clean is
   type Rec is record
      Value : Integer;
   end record;
   type Ptr is access Rec;

   P : Ptr := new Rec'(Value => 5);
begin
   P.Value := 6;
end Precision_Implicit_Deref_Clean;
