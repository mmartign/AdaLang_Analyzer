--  Precision regression for Uninitialized_Output (FP-183, libgfxinit): a
--  loop that goes round at least once -- a plain loop, or a for loop over
--  a static range, subtype or enumeration type that is not empty -- sets
--  an out parameter that its first pass sets before every exit and, for a
--  for loop, by the end of the pass. An array written whole (here as the
--  out actual of a call) counts as well.
procedure Precision_Uninitialized_Output_Loop_Exits_Clean is
   type PLL is (DPLL_A, DPLL_B, DPLL_C, Invalid);
   subtype DPLLs is PLL range DPLL_A .. DPLL_C;
   type Buffer is array (0 .. 3) of Integer;

   procedure Request (B : out Buffer; Ok : out Boolean) is
   begin
      B := (others => 1);
      Ok := True;
   end Request;

   --  "for Try in Positive range 1 .. 32 loop ... exit when Success;"
   procedure Retry (B : out Buffer; Ok : out Boolean) is
   begin
      for Try in Positive range 1 .. 32 loop
         Request (B, Ok);
         exit when Ok;
      end loop;
   end Retry;

   --  "for P in DPLLs loop Success := ...; if Success then return; ..."
   procedure Alloc (P : out PLL; Ok : out Boolean) is
   begin
      for Candidate in DPLLs loop
         Ok := Candidate = DPLL_B;
         if Ok then
            P := Candidate;
            return;
         end if;
      end loop;
      P := Invalid;
   end Alloc;

   --  A plain loop left only after the write.
   procedure Train (Ok : out Boolean) is
      Count : Natural := 0;
   begin
      loop
         Count := Count + 1;
         for I in 0 .. 3 loop
            Ok := I + Count > 4;
            exit when Ok or I = 3;
         end loop;
         exit when Ok or Count > 10;
      end loop;
   end Train;

   B  : Buffer;
   Ok : Boolean;
   P  : PLL;
begin
   Retry (B, Ok);
   Alloc (P, Ok);
   Train (Ok);
end Precision_Uninitialized_Output_Loop_Exits_Clean;
