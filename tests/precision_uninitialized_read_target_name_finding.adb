--  Uninitialized_Read: a target name, "@" (RM 5.2.1), reads the target of
--  its assignment, here before it has a value.

function Precision_Uninitialized_Read_Target_Name_Finding return Integer is
   T : Integer;
begin
   T := @ + 1;
   return T;
end Precision_Uninitialized_Read_Target_Name_Finding;
