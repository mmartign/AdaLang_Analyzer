--  Proof-path evidence: discriminant sub-boundary. A component selected from
--  an object whose own static discriminant constraint selects that
--  component's variant proves, including through an "others" alternative;
--  a statically excluded component is a definite error; a constant or
--  dynamic constraint leaves the obligation Unproved, never guessed.
procedure Verification_PP_Discriminant (K : Integer; Sink : out Integer) is
   type Kind_Type is (A_Kind, B_Kind, C_Kind);
   type Tagged_Rec (Kind : Kind_Type := A_Kind) is record
      case Kind is
         when A_Kind =>
            A_Val : Integer;
         when others =>
            O_Val : Integer;
      end case;
   end record;
   type Sized_Rec (N : Integer := 0) is record
      case N is
         when 0 .. 9 =>
            Small : Integer;
         when others =>
            Big : Integer;
      end case;
   end record;

   A_Constant : constant Kind_Type := A_Kind;

   Lit      : Tagged_Rec (Kind => B_Kind);
   Via_Name : Tagged_Rec (A_Constant);
   Sized    : Sized_Rec (5);
   Dynamic  : Sized_Rec (K);
begin
   Sink := Lit.O_Val;
   Sink := Via_Name.A_Val;
   Sink := Sized.Small;
   Sink := Sized.Big;
   Sink := Dynamic.Small;
end Verification_PP_Discriminant;
