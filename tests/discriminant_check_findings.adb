procedure Discriminant_Check_Findings is
   type Kind_Type is (Int_Kind, Float_Kind);
   type Variant_Rec (Kind : Kind_Type := Int_Kind) is record
      case Kind is
         when Int_Kind =>
            Int_Val : Integer;
         when Float_Kind =>
            Float_Val : Float;
      end case;
   end record;

   R : Variant_Rec (Kind => Int_Kind);
   F : Float;
begin
   F := R.Float_Val;
end Discriminant_Check_Findings;
