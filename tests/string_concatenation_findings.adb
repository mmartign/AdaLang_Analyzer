procedure String_Concatenation_Findings is
   Buffer : String := "";
begin
   for Index in 1 .. 3 loop
      Buffer := Buffer & "x";
   end loop;
end String_Concatenation_Findings;
