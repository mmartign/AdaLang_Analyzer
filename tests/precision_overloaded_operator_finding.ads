package Precision_Overloaded_Operator_Finding is
   type Vector is record
      X, Y : Integer;
   end record;
   function "+" (L, R : Vector) return Vector;
end Precision_Overloaded_Operator_Finding;
