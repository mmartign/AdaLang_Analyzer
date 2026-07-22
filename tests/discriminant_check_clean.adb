procedure Discriminant_Check_Clean is
   type Kind_Type is (Int_Kind, Float_Kind);
   type Variant_Rec (Kind : Kind_Type := Int_Kind) is record
      Common_Val : Integer;
      case Kind is
         when Int_Kind =>
            Int_Val : Integer;
         when Float_Kind =>
            Float_Val : Float;
      end case;
   end record;

   R : Variant_Rec (Kind => Int_Kind);
   I : Integer;
begin
   I := R.Int_Val;
   I := R.Common_Val;
end Discriminant_Check_Clean;
