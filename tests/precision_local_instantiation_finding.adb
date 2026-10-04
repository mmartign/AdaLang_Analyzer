with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Local_Instantiation_Finding is
   package Boxes is new Box (Item => Integer);
   R : Boxes.Ref := null;
begin
   R := new Integer'(1);
end Precision_Local_Instantiation_Finding;
