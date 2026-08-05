procedure Precision_Access_To_Object_Finding is
   type Ptr is access Integer;

   P : Ptr := new Integer'(5);
begin
   P.all := 6;
end Precision_Access_To_Object_Finding;
