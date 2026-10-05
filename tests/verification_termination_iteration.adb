--  Iteration over an array ends by itself, in a loop and in a quantified
--  expression: both functions are shown to return. Iteration through a
--  user-defined iterator calls its operations and is not followed.
procedure Verification_Termination_Iteration is
   type Vector is array (1 .. 4) of Integer;

   function Largest (Items : Vector) return Integer is
      Result : Integer := Items (1);
   begin
      for Item of Items loop
         if Item > Result then
            Result := Item;
         end if;
      end loop;
      return Result;
   end Largest;

   function All_Small (Items : Vector) return Boolean
   is (for all Item of Items => Item < 100);

   Data    : constant Vector := (others => 1);
   Outcome : Integer := 0;
begin
   if All_Small (Data) then
      Outcome := Largest (Data);
   end if;
   if Outcome > 1 then
      Outcome := 1;
   end if;
end Verification_Termination_Iteration;
