--  Proof-path evidence: attribute translation sub-boundary. 'Length on an
--  unconstrained array formal translates to a symbol lower-bounded at 0 and
--  can still prove; an attribute with an explicit dimension argument
--  remains unsupported.
procedure Verification_PP_Length_Attr
  (Data : String;
   Sink : out Integer)
with SPARK_Mode
is
begin
   Sink := 0;
   pragma Assert (Data'Length >= 0);
   pragma Assert (Data'Length (1) >= 0);
end Verification_PP_Length_Attr;
