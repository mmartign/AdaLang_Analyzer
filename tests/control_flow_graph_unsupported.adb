procedure Control_Flow_Graph_Unsupported (Limit : Integer) is
   Count : Integer := 0;
begin
   <<Again>>
   Count := Count + 1;
   if Count < Limit then
      goto Again;
   end if;
end Control_Flow_Graph_Unsupported;
