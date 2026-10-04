with Precision_Positional_Pkg; use Precision_Positional_Pkg;

procedure Precision_Positional_Generic_Parameter_Clean is
   package Ints is new Holder (Item => Integer, Zero => 0);
   package Boxes is new Box (Integer);
   R : Boxes.Ref := null;
begin
   Ints.Stored := 1;
   pragma Assert (Boxes."=" (R, null));
end Precision_Positional_Generic_Parameter_Clean;
