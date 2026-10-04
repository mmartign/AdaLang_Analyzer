with Precision_Gen_A;

generic
   type Item is private;
package Precision_Gen_B is
   package Refs is new Precision_Gen_A (Item => Item);
end Precision_Gen_B;
