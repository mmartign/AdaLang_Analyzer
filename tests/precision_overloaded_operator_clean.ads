package Precision_Overloaded_Operator_Clean is
   type Vector is record
      X, Y : Integer;
   end record;
   function Add (L, R : Vector) return Vector;
end Precision_Overloaded_Operator_Clean;
