--  FP-125: elaborating a package declared in a subprogram evaluates the
--  initial values of its declarations and runs the statements of its body,
--  or the declarations and statements of an instance of a generic package,
--  where the package is declared. Count counts its calls. Each assertion of
--  Local_Body, Local_Instance, Specification_Initializer and
--  Body_Initializer fails at run time; that of Local_Specification holds.
package Verification_FP125_Package_Elaboration is

   Calls : Integer := 0;
   function Count (X : Integer) return Integer;

   generic
      Start : Integer;
   package Counting is
      Value : Integer := Start;
   end Counting;

   procedure Local_Body;
   procedure Local_Instance;
   procedure Local_Specification;
   procedure Specification_Initializer;
   procedure Body_Initializer;

end Verification_FP125_Package_Elaboration;
