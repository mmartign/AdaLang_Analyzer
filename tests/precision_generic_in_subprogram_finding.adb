procedure Precision_Generic_In_Subprogram_Finding is
   generic
      type Item is private;
   procedure Swap (A, B : in out Item);

   procedure Swap (A, B : in out Item) is
      T : constant Item := A;
   begin
      A := B;
      B := T;
   end Swap;

   procedure Swap_Integers is new Swap (Integer);
   X : Integer := 1;
   Y : Integer := 2;
begin
   Swap_Integers (X, Y);
end Precision_Generic_In_Subprogram_Finding;
