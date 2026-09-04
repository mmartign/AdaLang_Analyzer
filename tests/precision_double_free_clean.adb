with Ada.Unchecked_Deallocation;

procedure Precision_Double_Free_Clean is
   type Int_Access is access all Integer;
   procedure Free is new Ada.Unchecked_Deallocation (Integer, Int_Access);

   P : Int_Access := new Integer'(1);
begin
   Free (P);
   P := new Integer'(2);
   Free (P);
end Precision_Double_Free_Clean;
