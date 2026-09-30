procedure Discriminant_Check_Clean is
   type Kind_Type is (Int_Kind, Float_Kind, Other_Kind);
   subtype Numeric_Kind is Kind_Type range Int_Kind .. Float_Kind;
   type Variant_Rec (Kind : Kind_Type := Int_Kind) is record
      Common_Val : Integer;
      case Kind is
         when Int_Kind =>
            Int_Val : Integer;
         when Float_Kind =>
            Float_Val : Float;
         when others =>
            null;
      end case;
   end record;
   type Fallback_Rec (Kind : Kind_Type := Int_Kind) is record
      case Kind is
         when Int_Kind =>
            First_Val : Integer;
         when others =>
            Rest_Val : Integer;
      end case;
   end record;
   type Subtype_Rec (Kind : Kind_Type := Int_Kind) is record
      case Kind is
         when Numeric_Kind =>
            Num_Val : Integer;
         when others =>
            Misc_Val : Integer;
      end case;
   end record;

   --  FP-083: a constant or subtype-name spelling differs from the literal
   --  it denotes, so neither may select the "others" variant by text.
   Int_Constant : constant Kind_Type := Int_Kind;

   R : Variant_Rec (Kind => Int_Kind);
   C : Fallback_Rec (Int_Constant);
   S : Subtype_Rec (Float_Kind);
   I : Integer;
begin
   I := R.Int_Val;
   I := R.Common_Val;
   I := C.First_Val;
   I := S.Num_Val;
end Discriminant_Check_Clean;
