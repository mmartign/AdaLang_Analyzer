procedure H15 (A : in out String; N : Integer; M : Integer; Sink : out Integer) is
   type Arr is array (1 .. 4) of Integer;
   T : Arr := (others => 1);
   X : Integer := 0;
   Y : Integer := 0;
   Prev : Integer := 0;
   Count : Integer := 0;
begin
   Sink := 0;
   --  values read from array elements are independent unknowns
   if N in 1 .. 4 and then M in 1 .. 4 then
      X := T (N);
      Y := T (M);
      if X = Y then
         Sink := 1;
      else
         Sink := 10 / (N - M);                    --  OK
      end if;
      pragma Assert (X = Y);                      --  BAD:assertion
   end if;
   --  the same read on two iterations
   for I in 1 .. 4 loop
      X := T (I);
      if I > 1 then
         pragma Assert (X = Prev);                --  BAD:assertion
      end if;
      Prev := X;
   end loop;
   --  an element write keeps scalar facts, and changes the element
   X := 5;
   T (1) := 0;
   Sink := 10 / X;                                --  OK
   Y := T (1);
   Sink := 10 / (Y + 0);                          --  BAD
   T (2) := 7;
   Y := T (2);
   T (2) := 0;
   X := T (2);
   pragma Assert (X = Y);                         --  BAD:assertion
   --  array declared inside a loop: bounds differ per iteration
   for I in 1 .. 3 loop
      declare
         B : String (1 .. I) := (others => ' ');
      begin
         if B'Last = 1 then
            Count := Count + 1;
         end if;
         Sink := Character'Pos (B (1));           --  OK:index-check
         Sink := Character'Pos (B (2));           --  BAD:index-check
         if B'Length >= 2 then
            Sink := Character'Pos (B (2));        --  OK:index-check
            Sink := Character'Pos (B (3));        --  BAD:index-check
         end if;
      end;
   end loop;
   --  facts about a parameter's bounds across a loop that changes a scalar
   if A'Length = 3 then
      X := A'First;
      for I in 1 .. 5 loop
         X := X + 1;
      end loop;
      Sink := Character'Pos (A (A'First + 2));    --  OK:index-check
      Sink := Character'Pos (A (X));              --  BAD:index-check
      Sink := Character'Pos (A (A'First + 3));    --  BAD:index-check
   end if;
   --  loop bounds that are not fixed
   Y := A'Last;
   for I in A'First .. Y loop
      Y := Y + 1;
      Sink := Character'Pos (A (I));              
   end loop;
   for I in A'First .. Y loop
      Sink := Character'Pos (A (I));              --  BAD:index-check
   end loop;
   --  whole-object assignment keeps bounds
   A := (others => 'x');
   for I in A'Range loop
      Sink := Character'Pos (A (I));              --  OK:index-check
   end loop;
end H15;
