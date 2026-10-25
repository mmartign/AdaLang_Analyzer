--  A constant whose value can change behind its name has no value the
--  analysis knows, whatever its initializer: a volatile constant, and one
--  laid over a variable by an address clause. Not SPARK.
package Verification_Static_Constants_External is
   Counter : Natural := 8;
   Port    : constant Natural := 8 with Volatile;
   Overlay : constant Natural := 8 with Address => Counter'Address;

   procedure Bad_Volatile (W : out Integer);
   procedure Bad_Overlay (W : out Integer);
end Verification_Static_Constants_External;
