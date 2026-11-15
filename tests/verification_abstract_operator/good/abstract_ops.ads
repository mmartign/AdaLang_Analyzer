--  RecordFlux declares "+" (Index, Index) abstract so that index arithmetic
--  goes through an operator of a formal package that takes a Length.
--  Libadalang resolves First + 1 to the abstract one, which no call can
--  denote (RM 6.4(8/2)); the call is to the expression function of
--  Operators, which returns. GNATprove 16.1.0 proves every Always_Terminates.
generic
   type Custom_Index is range <>;
   type Custom_Length is range <>;
package Abstract_Ops with SPARK_Mode, Always_Terminates is
   subtype Index is Custom_Index;
   subtype Length is Custom_Length;
   function "+" (Left : Index; Right : Index) return Index is abstract;
end Abstract_Ops;
