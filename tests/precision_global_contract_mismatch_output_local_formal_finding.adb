--  At the shape of the libkeccak regression (FP-189): the nested procedure
--  reads a local it lists as Output before it writes it, the generic
--  formal function called around it notwithstanding. Must fire.
procedure Precision_Global_Contract_Mismatch_Output_Local_Formal_Finding
  with SPARK_Mode
is
   generic
      type Lane is private;
      with function Mix (A, B : Lane) return Lane;
   package Perm is
      procedure Run (A, B : in out Lane);
   end Perm;

   package body Perm is
      procedure Run (A, B : in out Lane) is
         Ca     : Lane := A;
         E1, E2 : Lane := B;

         procedure Step
           with Global => (Input  => Ca,
                           Output => (E1, E2))
         is
            T : Lane;
         begin
            T := Mix (Ca, Ca);
            E1 := Mix (E2, T);
            E2 := Mix (E1, T);
         end Step;
      begin
         Step;
         A := E1;
         B := E2;
      end Run;
   end Perm;
begin
   null;
end Precision_Global_Contract_Mismatch_Output_Local_Formal_Finding;
