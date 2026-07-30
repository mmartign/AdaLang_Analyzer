procedure Precision_Deep_Nesting_Over_Threshold (X : Integer) is
begin
   if X = 1 then
      if X = 2 then
         if X = 3 then
            if X = 4 then
               if X = 5 then
                  null;
               end if;
            end if;
         end if;
      end if;
   end if;
end Precision_Deep_Nesting_Over_Threshold;
