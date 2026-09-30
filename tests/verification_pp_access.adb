--  Proof-path evidence: composite and access sub-boundary. A component
--  fact written through one access value holds for a read through that same
--  value, but a write through a second access value that may designate the
--  same object discards it rather than preserving it. Array-of-record
--  indexing and component range checks prove from resolved subtypes;
--  record aggregates stay outside the scalar VC subset.
package body Verification_PP_Access with SPARK_Mode is
   procedure Solo (A : Rec_Ptr; Sink : out Integer) is
   begin
      A.F := 11;
      Sink := A.F + 1;
   end Solo;

   procedure Aliased_Write (C, D : Rec_Ptr; Sink : out Integer) is
   begin
      C.F := 1;
      D.F := Integer'Last;
      Sink := C.F + 1;
   end Aliased_Write;

   procedure Records (V : in out Rec_Arr; X : Integer; Sink : out Integer)
   is
      J : constant Integer := 2;
      K : Integer := 4;
      P : Rec := (F => X, N => 1);
   begin
      V (J).N := 7;
      V (J).F := -7;
      V (J) := P;
      Sink := V (J).F;
      V (1).N := J - 3;
      Sink := V (K).F;
   end Records;
end Verification_PP_Access;
