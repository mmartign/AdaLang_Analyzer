--  Duplicate_Condition: the same test twice, with only reads between, is a
--  duplicate (simple_components' Julia binding checks Box_Int8 for
--  jl_box_int32).

procedure Precision_Duplicate_Condition_Pure_Finding
  (Box_Int8, Box_Int16, Box_Int32 : Integer; Missing : out String)
is
begin
   if Box_Int8 = 0 then
      Missing := "jl_box_int8 ";
   elsif Box_Int16 = 0 then
      Missing := "jl_box_int16";
   elsif Box_Int8 = 0 then
      Missing := "jl_box_int32";
   else
      Missing := (others => ' ');
   end if;
end Precision_Duplicate_Condition_Pure_Finding;
