--  As in good, but the "+" of Operators loops: the calls of it are not
--  shown to return. GNATprove 16.1.0 reports the loop of "+".
generic
   type Custom_Index is range <>;
   type Custom_Length is range <>;
package Abstract_Ops with SPARK_Mode, Always_Terminates is
   subtype Index is Custom_Index;
   subtype Length is Custom_Length;
   function "+" (Left : Index; Right : Index) return Index is abstract;
end Abstract_Ops;
