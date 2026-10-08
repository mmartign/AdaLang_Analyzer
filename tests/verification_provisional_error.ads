--  While a loop is iterated to its fixed point, a state is one that some
--  path reaches and not yet the join of all of them. Two counters that
--  run together are, for a few iterations, as far apart as they are after
--  one iteration only, and the assertion after the loop is then false of
--  what the state holds. It is not a definite error on that showing, nor
--  is the proof of it from another such state a contradiction for which
--  the subprogram is given up.
package Verification_Provisional_Error with SPARK_Mode is

   type Byte is mod 2 ** 8;
   subtype Index_64 is Integer range 0 .. 63;
   type Byte_Seq is array (Integer range <>) of Byte;
   subtype Bytes_64 is Byte_Seq (Index_64);

   procedure Walk (Data : in out Bytes_64);

   --  The loop may not run at all, and Count is then zero: the assertion
   --  may fail, and is no definite error, since it holds whenever the loop
   --  runs. The division after it is made with what it asserts.
   procedure Counted (Rounds : Integer; Sink : out Integer);

end Verification_Provisional_Error;
