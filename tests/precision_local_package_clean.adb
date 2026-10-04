package body Precision_Local_Package_Clean is
   package Inner is
      Limit : constant Integer := 10;
   end Inner;

   function Limit return Integer is (Inner.Limit);
end Precision_Local_Package_Clean;
