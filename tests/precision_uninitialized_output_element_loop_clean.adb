--  An element iterator that assigns its loop parameter on every pass sets
--  every element of the out parameter it iterates over, even when that is
--  empty ("for C of Buffer loop C := ' '; end loop;", Ironclad's
--  Messages.Dump_Logs and Cryptography.Random.Fill_Data, FP-193).
procedure Precision_Uninitialized_Output_Element_Loop_Clean
  (Buffer : out String; Codes : out String; Seed : Natural)
is
   Mini : Natural := Seed;
begin
   for C of Buffer loop
      C := ' ';
   end loop;
   for Value of Codes loop
      if Mini > 3 then
         Mini := 0;
      end if;
      case Mini is
         when 0 => Value := 'a';
         when others => null;
      end case;
      Value := Character'Val (65 + Mini);
      Mini := Mini + 1;
   end loop;
end Precision_Uninitialized_Output_Element_Loop_Clean;
