procedure Precision_No_Unchecked_Access_Clean is
   type Int_Access is access all Integer;
   X : aliased Integer := 5;
   P : Int_Access;
begin
   P := X'Access;
end Precision_No_Unchecked_Access_Clean;
