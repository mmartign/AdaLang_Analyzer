with Ada.Unchecked_Deallocation;

procedure Precision_Use_After_Free_Finding is
   type Int_Access is access all Integer;
   procedure Free is new Ada.Unchecked_Deallocation (Integer, Int_Access);

   P : Int_Access := new Integer'(1);
   X : Integer;
begin
   Free (P);
   X := P.all;
end Precision_Use_After_Free_Finding;
