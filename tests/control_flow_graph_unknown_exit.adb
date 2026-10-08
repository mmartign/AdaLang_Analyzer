procedure Control_Flow_Graph_Unknown_Exit (Leave : Boolean) is
begin
   loop
      exit Elsewhere when Leave;
   end loop;
end Control_Flow_Graph_Unknown_Exit;
