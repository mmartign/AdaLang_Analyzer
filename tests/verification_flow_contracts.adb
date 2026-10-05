--  A subprogram with a Global aspect reads and writes no outside object the
--  aspect does not allow, counting what the subprograms it calls do, by
--  their own aspect or, when they have none, by their body. A global of
--  mode Output is assigned on every path. Each contract below holds.
procedure Verification_Flow_Contracts
  with SPARK_Mode
is
   Source  : Integer := 1;
   Counter : Integer := 0;
   Result  : Integer := 0;

   procedure Copy
     with Global => (Input => Source, Output => Result)
   is
   begin
      Result := Source;
   end Copy;

   procedure Bump
     with Global => (In_Out => Counter)
   is
   begin
      if Counter < 100 then
         Counter := Counter + 1;
      end if;
   end Bump;

   procedure Checked (Value : out Integer)
     with Global => (Proof_In => Source),
          Pre    => Source > 0
   is
   begin
      pragma Assert (Source > 0);
      Value := 0;
   end Checked;

   --  A Depends aspect has an obligation of its own.
   procedure Scaled (Factor : Integer; Value : out Integer)
     with Global  => (Input => Source),
          Depends => (Value => (Factor, Source))
   is
   begin
      Value := (if Factor > 0 then Source else 0);
   end Scaled;

   --  By the aspects of what it calls.
   procedure Through
     with Global => (Input => Source, Output => Result, In_Out => Counter)
   is
   begin
      Copy;
      Bump;
   end Through;

   --  No aspect: its body says what it reads.
   procedure Helper (Value : out Integer) is
   begin
      Value := Source;
   end Helper;

   procedure By_Body (Value : out Integer)
     with Global => (Input => Source)
   is
   begin
      Helper (Value);
   end By_Body;

   procedure Nothing (Value : out Integer)
     with Global => null
   is
   begin
      Value := 0;
   end Nothing;

   Outcome : Integer;
begin
   Checked (Outcome);
   Through;
   By_Body (Outcome);
   Nothing (Outcome);
   Scaled (1, Outcome);
   Source := Outcome;
end Verification_Flow_Contracts;
