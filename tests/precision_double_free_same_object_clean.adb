--  Double_Free: a second Free of the same object is not a double free. The
--  first call sets P to null (RM 13.11.2), and freeing null does nothing:
--  the handler that frees what the block allocated may run after the
--  block has freed it already (Zip-Ada's BZip2 and LZMA encoders).

with Ada.Unchecked_Deallocation;

procedure Precision_Double_Free_Same_Object_Clean (Fail : Boolean) is
   type Int_Access is access all Integer;
   procedure Free is new Ada.Unchecked_Deallocation (Integer, Int_Access);

   P : Int_Access := new Integer'(1);
begin
   Free (P);
   if Fail then
      raise Constraint_Error;
   end if;
exception
   when others =>
      Free (P);
      raise;
end Precision_Double_Free_Same_Object_Clean;
