package body Verification_FP124_Iteration is

   function First (B : Bag) return Integer is (1);
   function Next (B : Bag; C : Integer) return Integer is (C + 1);
   function Has_Element (B : Bag; C : Integer) return Boolean is
     (C <= B.Count);

   function Element (B : Bag; C : Integer) return Integer is
   begin
      Calls := Calls + 1;
      return C;
   end Element;

   procedure Loop_Over (B : Bag) is
      Sum : Integer := 0;
   begin
      Calls := 0;
      for E of B loop
         Sum := Sum + E;
      end loop;
      pragma Assert (Calls = 0);
   end Loop_Over;

   procedure Assert_Over (B : Bag) is
   begin
      Calls := 0;
      pragma Assert (for all E of B => E > 0);
      pragma Assert (Calls + 0 = 0);
   end Assert_Over;

   procedure Quantify_Over (B : Bag) is
      All_Positive : Boolean;
   begin
      Calls := 0;
      All_Positive := (for all E of B => E > 0);
      pragma Assert (0 = Calls);
   end Quantify_Over;

   procedure Range_Loop is
      Sum : Integer := 0;
   begin
      Calls := 0;
      for I in 1 .. 3 loop
         Sum := Sum + I;
      end loop;
      pragma Assert (Calls - 0 = 0);
   end Range_Loop;

   procedure Array_Loop (A : Arr) is
      Sum : Integer := 0;
   begin
      Calls := 0;
      for E of A loop
         Sum := Sum + E mod 10;
      end loop;
      pragma Assert (Calls * 1 = 0);
   end Array_Loop;

end Verification_FP124_Iteration;
