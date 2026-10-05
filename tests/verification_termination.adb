--  A function, and a procedure with Always_Terminates, must return. Each
--  subprogram below does: no loop but a for loop over a range, no
--  recursion, and nothing called but subprograms that return.
procedure Verification_Termination
  with SPARK_Mode
is
   function Leaf (Value : Integer) return Integer
   is (if Value < 0 then 0 else Value);

   function Counted (Limit : Natural) return Natural is
      Count : Natural := 0;
   begin
      for Step in 1 .. Limit loop
         if Count < 10 then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Counted;

   function Through_Calls (Value : Integer) return Integer
   is (if Counted (3) < 5 then Leaf (Value) else 0);

   procedure Settle (Value : in out Integer)
     with Always_Terminates
   is
   begin
      Value := Leaf (Value);
   end Settle;

   Outcome : Integer;
begin
   Outcome := Through_Calls (7);
   Settle (Outcome);
end Verification_Termination;
