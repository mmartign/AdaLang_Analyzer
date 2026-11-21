--  Double_Free: Q, a copy of P made before P is freed, still designates
--  the freed object, and freeing it frees that object a second time.

with Ada.Unchecked_Deallocation;

procedure Precision_Double_Free_Finding is
   type Int_Access is access all Integer;
   procedure Free is new Ada.Unchecked_Deallocation (Integer, Int_Access);

   P : Int_Access := new Integer'(1);
   Q : Int_Access := P;
begin
   Free (P);
   Free (Q);
end Precision_Double_Free_Finding;
