--  Global aspects that do not cover what the subprogram does, and Output
--  globals that are not assigned on every path. None of the checks below
--  may be proved.
procedure Verification_Mutation_Flow_Contracts
  with SPARK_Mode
is
   type Pair is record
      First, Second : Integer;
   end record;

   Source  : Integer := 1;
   Counter : Integer := 0;
   Result  : Integer := 0;
   Maybe   : Integer := 0;
   Both    : Pair := (0, 0);

   --  It reads Source.
   procedure Unlisted_Read
     with Global => (Output => Result)
   is
   begin
      Result := Source;
   end Unlisted_Read;

   --  It writes Counter, listed as an input.
   procedure Input_Written
     with Global => (Input => Counter)
   is
   begin
      Counter := 0;
   end Input_Written;

   --  It reads Source outside an assertion.
   procedure Proof_In_Read (Value : out Integer)
     with Global => (Proof_In => Source)
   is
   begin
      Value := Source;
   end Proof_In_Read;

   procedure Helper (Value : out Integer) is
   begin
      Value := Source;
   end Helper;

   --  What it calls reads Source.
   procedure Unlisted_By_Call (Value : out Integer)
     with Global => null
   is
   begin
      Helper (Value);
   end Unlisted_By_Call;

   --  One path leaves Maybe alone.
   procedure Sometimes (Chosen : Boolean)
     with Global => (Output => Maybe)
   is
   begin
      if Chosen then
         Maybe := 1;
      end if;
   end Sometimes;

   --  Value depends on Factor too.
   procedure Scaled (Factor : Integer; Value : out Integer)
     with Global  => (Input => Source),
          Depends => (Value => Source, null => Factor)
   is
   begin
      Value := (if Factor > 0 then Source else 0);
   end Scaled;

   --  One component is not the whole object.
   procedure Half
     with Global => (Output => Both)
   is
   begin
      Both.First := 1;
   end Half;

   Outcome : Integer;
begin
   Unlisted_Read;
   Input_Written;
   Proof_In_Read (Outcome);
   Unlisted_By_Call (Outcome);
   Sometimes (Outcome > 0);
   Half;
   Scaled (1, Outcome);
   Source := (if Outcome > Maybe then Both.First else 0);
end Verification_Mutation_Flow_Contracts;
