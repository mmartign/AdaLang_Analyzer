with Ada.Unchecked_Deallocation;

procedure Precision_Unchecked_Deallocation_Finding is
   type Int_Access is access Integer;
   procedure Free is new Ada.Unchecked_Deallocation (Integer, Int_Access);
   P : Int_Access := new Integer'(0);
begin
   Free (P);
end Precision_Unchecked_Deallocation_Finding;
