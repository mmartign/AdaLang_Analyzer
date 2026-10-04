with Precision_Positional_Pkg;

generic
   with package Ints is new Precision_Positional_Pkg.Holder
     (Item => Integer, Zero => <>);
package Precision_Ada05_Formal_Package_Finding is
   Copy : Integer := Ints.Stored;
end Precision_Ada05_Formal_Package_Finding;
