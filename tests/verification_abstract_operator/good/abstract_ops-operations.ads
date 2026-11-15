with Abstract_Ops.Operators;
generic
   with package Ops is new Abstract_Ops.Operators (<>);
package Abstract_Ops.Operations with SPARK_Mode, Always_Terminates is
   use Ops;
   procedure Walk (First, Last : Index; Count : out Natural);
end Abstract_Ops.Operations;
