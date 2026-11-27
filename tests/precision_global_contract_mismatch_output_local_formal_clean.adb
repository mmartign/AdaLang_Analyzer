--  Precision regression for Global_Contract_Mismatch (FP-189, libkeccak's
--  Keccak.Generic_Parallel_KeccakF): a nested procedure lists locals of the
--  enclosing body as Output and reads them after writing them, while it
--  calls a generic formal function whose effects are not known. No
--  subprogram declared outside that body can name its locals, so the call
--  cannot read them first. Must not fire.
procedure Precision_Global_Contract_Mismatch_Output_Local_Formal_Clean
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
         E1, E2 : Lane;

         procedure Step
           with Global => (Input  => Ca,
                           Output => (E1, E2))
         is
            T : Lane;
         begin
            T := Mix (Ca, Ca);
            E1 := Mix (T, Ca);
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
end Precision_Global_Contract_Mismatch_Output_Local_Formal_Clean;
