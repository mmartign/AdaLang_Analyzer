procedure Control_Flow_Graph_Forward_Goto
  (Skip : Boolean; Result : out Integer) is
begin
   Result := 0;
   if Skip then
      goto Finished;
   end if;
   Result := 1;

   <<Finished>>
   null;
end Control_Flow_Graph_Forward_Goto;
