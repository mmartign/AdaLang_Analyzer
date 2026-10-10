--  FP-119: a component read in an element of an array was one symbol for
--  every element. The object an indexed component resolves to is the
--  array, and the symbol was keyed by that object and the component alone,
--  so that "Row (1).Count" and "Row (2).Count" were the same value
--  whatever the two elements hold. Two of them were proved equal, and a
--  condition no element contradicts was taken for one that cannot hold,
--  under which everything is proved.
package Verification_FP119_Element_Component with SPARK_Mode => On is

   type Item is record
      Count : Integer;
      Limit : Integer;
   end record;

   type Items is array (1 .. 2) of Item;

   procedure Two_Elements (Row : Items);
   procedure Across_Elements (Mixed : Items; Share : Integer; Part : out Integer);
   procedure One_Element (Same : Items);

end Verification_FP119_Element_Component;
