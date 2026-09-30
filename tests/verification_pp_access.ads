--  Proof-path evidence: composite and access sub-boundary (see the body).
package Verification_PP_Access with SPARK_Mode is
   type Rec is record
      F : Integer;
      N : Natural;
   end record;
   type Rec_Ptr is access Rec;
   type Rec_Arr is array (1 .. 3) of Rec;

   procedure Solo (A : Rec_Ptr; Sink : out Integer);
   procedure Aliased_Write (C, D : Rec_Ptr; Sink : out Integer);
   procedure Records (V : in out Rec_Arr; X : Integer; Sink : out Integer);
end Verification_PP_Access;
