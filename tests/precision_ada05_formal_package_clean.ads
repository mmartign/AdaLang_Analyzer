with Precision_Positional_Pkg;

generic
   with package Ints is new Precision_Positional_Pkg.Holder (<>);
   with package Fixed is new Precision_Positional_Pkg.Holder
     (Item => Integer, Zero => 0);
package Precision_Ada05_Formal_Package_Clean is
   Copy : Integer := Fixed.Stored;
end Precision_Ada05_Formal_Package_Clean;
