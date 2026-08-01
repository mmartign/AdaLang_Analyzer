procedure Depends_Combined_Output_Clean (A, B : out Integer; C : in Integer)
  with Depends => ((A, B) => C)
is
   --  "(A, B) => C" is a combined-output Depends association: two outputs
   --  sharing one input list. Ada's own aggregate grammar has no comma-
   --  separated choice list (only "|" separates multiple discrete
   --  choices), so Libadalang parses the parenthesized "A, B" as a nested
   --  positional aggregate rather than as two designators. A parser that
   --  only understood a single plain identifier per designator would
   --  silently drop both outputs, wrongly reporting them as missing from
   --  Depends and misreporting their shared input as unused.
begin
   A := C;
   B := C;
end Depends_Combined_Output_Clean;
