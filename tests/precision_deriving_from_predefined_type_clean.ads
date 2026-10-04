with Ada.Streams;

package Precision_Deriving_From_Predefined_Type_Clean is
   type Base is range 0 .. 100;
   type Metres is new Base;
   type Frame is new Ada.Streams.Stream_Element_Array (1 .. 8);
end Precision_Deriving_From_Predefined_Type_Clean;
