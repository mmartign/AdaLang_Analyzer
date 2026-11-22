--  A dispatching call with no actual ("S.Area") runs the body of the
--  actual's type, not the root's, which raises only to say that it is to be
--  overridden (gnatcoll's Instance.Get_User_Data): Measure does not take the
--  root's raise from it, and Exception_Propagation must not fire at the
--  call of Measure.
procedure Precision_Exception_Propagation_Dispatching_No_Actual_Clean is
   package Shapes is
      type Shape is tagged null record;
      function Area (S : Shape) return Integer;
      type Square is new Shape with null record;
      overriding function Area (S : Square) return Integer;
   end Shapes;

   package body Shapes is
      function Area (S : Shape) return Integer is
         pragma Unreferenced (S);
      begin
         raise Program_Error with "Area should be overridden";
         return 0;
      end Area;

      overriding function Area (S : Square) return Integer is
         pragma Unreferenced (S);
      begin
         return 4;
      end Area;
   end Shapes;

   function Measure (S : Shapes.Shape'Class; N : Integer) return Integer is
   begin
      return S.Area + N;
   end Measure;

   Q : Shapes.Square;
   X : Integer;
begin
   X := Measure (Q, 1);
   pragma Assert (X = 5);
end Precision_Exception_Propagation_Dispatching_No_Actual_Clean;
