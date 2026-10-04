package body Precision_Design is
   Local_Failure : exception;

   package Ints is new Holder (Integer, 0, 2);

   procedure Reset (This : in out Root) is
   begin
      This.Count := 0;
   end Reset;

   procedure Bump (This : in out Root) is
   begin
      This.Count := This.Count + 1;
   end Bump;

   overriding procedure Reset (This : in out Child) is
   begin
      Reset (Root (This));
      Bump (This);
   end Reset;

   overriding procedure Bump (This : in out Child) is
   begin
      This.Count := This.Count + 2;
   end Bump;

   procedure Run (Value : in Index; R : in out Root'Class) is
      Total : Integer := Ints.Stored;
   begin
      if Value in Index then
         Total := Total + 1;
      end if;
      if Value in Index'First .. Index'Last then
         Total := Total + 1;
      end if;
      if Total = Tolerance then
         raise Hidden_Failure;
      end if;
      if Total > 20 then
         raise Local_Failure;
      end if;
      if Total > 30 then
         raise Private_Failure;
      end if;
      for I in 1 .. 3 loop
         Total := Total + I;
      end loop;
      Reset (Child (R));
      Bump (R);
   exception
      when Private_Failure =>
         null;
   end Run;
end Precision_Design;
