--  Proof-path evidence: own-range index sub-boundary. Indexing an array
--  object with the parameter of a loop over that same object's own range
--  proves whatever the object's bounds are, including for an unconstrained
--  formal; the parameter of a loop over another object's range, an offset
--  from the parameter, the wrong dimension, or a same-named inner object
--  proves nothing.
procedure Verification_PP_Index_Own_Range
  (Data  : String;
   Other : String;
   Sink  : out Integer)
with SPARK_Mode
is
   type Grid is array (Positive range <>, Positive range <>) of Integer;

   procedure Sum (Cells : Grid; Total : in out Integer) is
   begin
      for Row in Cells'Range (1) loop
         for Column in Cells'Range (2) loop
            Total := Cells (Row, Column);
         end loop;
      end loop;
      for Swapped in Cells'Range (2) loop
         Total := Cells (Swapped, Cells'First (2));
      end loop;
   end Sum;
begin
   Sink := 0;
   for Own in Data'Range loop
      Sink := Character'Pos (Data (Own));
   end loop;
   for Spelled in Data'First .. Data'Last loop
      Sink := Character'Pos (Data (Spelled));
   end loop;
   for Backward in reverse Data'Range loop
      Sink := Character'Pos (Data (Backward));
   end loop;
   for Foreign in Other'Range loop
      Sink := Character'Pos (Data (Foreign));
   end loop;
   for Mixed in Data'First .. Other'Last loop
      Sink := Character'Pos (Data (Mixed));
   end loop;
   for Shifted in Data'Range loop
      Sink := Character'Pos (Data (Shifted + 1));
   end loop;
   for Shadowed in Data'Range loop
      declare
         Data : constant String := "ab";
      begin
         Sink := Character'Pos (Data (Shadowed));
      end;
   end loop;
   Sum ((1 => (1 => 0)), Sink);
end Verification_PP_Index_Own_Range;
