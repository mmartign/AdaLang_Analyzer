--  Two package specifications in one file, as an ObjectAda project can
--  hold them, that with each other: a cycle between two compilation units
--  of the same file.
with Circular_Multi_Beta;
package Circular_Multi_Alpha is
   Size : constant := Circular_Multi_Beta.Size + 1;
end Circular_Multi_Alpha;

with Circular_Multi_Alpha;
package Circular_Multi_Beta is
   Size : constant := 4;
   Twice : constant := 2 * Circular_Multi_Alpha.Size;
end Circular_Multi_Beta;
