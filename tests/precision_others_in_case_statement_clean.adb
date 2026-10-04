procedure Precision_Others_In_Case_Statement_Clean (X : Boolean) is
   type Table is array (1 .. 3) of Integer;
   Y : Table := (others => 0);
   Z : constant Integer := (case X is when True => 1, when others => 2);
begin
   case X is
      when True =>
         Y (1) := Z;
      when False =>
         Y (2) := Z;
   end case;
exception
   when others =>
      null;
end Precision_Others_In_Case_Statement_Clean;
