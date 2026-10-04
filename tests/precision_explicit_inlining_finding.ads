package Precision_Explicit_Inlining_Finding is
   function Twice (N : in Integer) return Integer with Inline;
   function Thrice (N : in Integer) return Integer;
   pragma Inline (Thrice);
end Precision_Explicit_Inlining_Finding;
