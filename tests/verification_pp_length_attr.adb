--  Proof-path evidence: attribute translation sub-boundary. 'Length on an
--  unconstrained array formal translates to a symbol lower-bounded at 0 and
--  can still prove, with or without a literal dimension; a dimension given
--  by a named number remains unsupported. The array is indexed by an
--  enumeration type: of one indexed by an integer subtype the limits of the
--  length are known from the subtype, with no translation.
procedure Verification_PP_Length_Attr
  (Sink : out Integer)
with SPARK_Mode
is
   type Channel is (Red, Green, Blue);
   type Levels is array (Channel range <>) of Integer;

   Dim : constant := 1;

   procedure Check (Data : Levels) is
   begin
      pragma Assert (Data'Length >= 0);
      pragma Assert (Data'Length (1) >= 0);
      pragma Assert (Data'Length (Dim) >= 0);
   end Check;
begin
   Sink := 0;
   Check ((Red .. Green => 0));
end Verification_PP_Length_Attr;
