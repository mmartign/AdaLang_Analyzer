--  Use_After_Free: Q, a copy of P made before P is freed, designates the
--  freed object; reading through it reads freed storage.

with Ada.Unchecked_Deallocation;

procedure Precision_Use_After_Free_Copy_Finding (X : out Integer) is
   type Int_Access is access all Integer;
   procedure Free is new Ada.Unchecked_Deallocation (Integer, Int_Access);

   P : Int_Access := new Integer'(1);
   Q : Int_Access;
begin
   Q := P;
   Free (P);
   X := Q.all;
end Precision_Use_After_Free_Copy_Finding;
