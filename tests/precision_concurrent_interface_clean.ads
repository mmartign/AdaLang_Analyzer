package Precision_Concurrent_Interface_Clean is
   type Queue is limited interface;
   procedure Put (Q : in out Queue; X : in Integer) is abstract;
end Precision_Concurrent_Interface_Clean;
