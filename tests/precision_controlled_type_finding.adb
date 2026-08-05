with Ada.Finalization;

procedure Precision_Controlled_Type_Finding is
   type Managed is new Ada.Finalization.Controlled with null record;
   X : Managed;
begin
   null;
end Precision_Controlled_Type_Finding;
