--  Duplicate_Condition: a condition the same as an earlier one is no
--  duplicate where a condition between them calls a function that changes
--  what it reads (ada_toml's parser reads the next codepoint).

function Precision_Duplicate_Condition_Effect_Clean (S : String) return Integer is
   Pos : Natural := S'First;
   Cur : Character := ' ';
   function Read return Boolean is
   begin
      if Pos > S'Last then
         return False;
      end if;
      Cur := S (Pos);
      Pos := Pos + 1;
      return True;
   end Read;
begin
   if Cur /= '"' then
      return 1;
   elsif not Read then
      return 2;
   elsif Cur /= '"' then
      return 3;
   end if;
   return 0;
end Precision_Duplicate_Condition_Effect_Clean;
