--  At the same shape, a pass that can end before the assignment (here an
--  exit), or an assignment on some passes only, leaves elements unset.
procedure Precision_Uninitialized_Output_Element_Loop_Finding
  (Buffer : out String; Codes : out String; Stop : Character)
is
begin
   for C of Buffer loop
      exit when Stop = 'x';
      C := ' ';
   end loop;
   for Value of Codes loop
      if Stop = 'y' then
         Value := ' ';
      end if;
   end loop;
end Precision_Uninitialized_Output_Element_Loop_Finding;
