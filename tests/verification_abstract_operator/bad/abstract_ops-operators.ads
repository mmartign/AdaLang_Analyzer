generic
package Abstract_Ops.Operators with SPARK_Mode, Always_Terminates is
   function "+" (Left : Index; Right : Length) return Index
   with Pre => Length (Left) <= Length'Last - Right;
end Abstract_Ops.Operators;
