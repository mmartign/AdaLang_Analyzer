with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
procedure String_Concatenation_Clean is
   Buffer : String := "";
   Total  : Integer := 0;
   Built  : Unbounded_String;
begin
   Buffer := Buffer & "x";

   for Index in 1 .. 3 loop
      Total := Total + Index;
   end loop;

   for Index in 1 .. 3 loop
      Built := Built & "x";
   end loop;
end String_Concatenation_Clean;
