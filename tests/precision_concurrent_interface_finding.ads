package Precision_Concurrent_Interface_Finding is
   type Queue is synchronized interface;
   procedure Put (Q : in out Queue; X : in Integer) is abstract;
end Precision_Concurrent_Interface_Finding;
