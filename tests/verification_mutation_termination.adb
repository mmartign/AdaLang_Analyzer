--  Subprograms that must return and are not shown to: a loop with no bound,
--  recursion, direct and mutual, and a call to one of those. None of the
--  termination checks below may be proved.
procedure Verification_Mutation_Termination
  with SPARK_Mode
is
   function Halving (Start : Natural) return Natural is
      Count : Natural := Start;
   begin
      while Count > 10 loop
         Count := Count / 2;
      end loop;
      return Count;
   end Halving;

   function Descending (Depth : Natural) return Natural is
   begin
      if Depth = 0 then
         return 0;
      end if;
      return Descending (Depth - 1);
   end Descending;

   function Pong (Depth : Natural) return Natural;

   function Ping (Depth : Natural) return Natural
   is (if Depth = 0 then 0 else Pong (Depth - 1));

   function Pong (Depth : Natural) return Natural
   is (if Depth = 0 then 0 else Ping (Depth - 1));

   --  It calls a function that is not shown to return.
   function Relying (Depth : Natural) return Natural
   is (Descending (Depth));

   procedure Spinning (Value : in out Integer)
     with Always_Terminates
   is
   begin
      loop
         exit when Value > 10;
         Value := 11;
      end loop;
   end Spinning;

   Outcome : Integer := 3;
begin
   Outcome := Halving (Outcome) + Ping (2) + Relying (1);
   Spinning (Outcome);
end Verification_Mutation_Termination;
