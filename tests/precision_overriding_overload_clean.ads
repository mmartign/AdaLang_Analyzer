--  Negative fixture: Draw (Self : Circle; Scale : Float) does not match the
--  profile of any inherited primitive, so it overloads Draw rather than
--  overriding it. It must not be reported as missing the overriding keyword.
package Precision_Overriding_Overload_Clean is
   type Shape is tagged null record;
   procedure Draw (Self : Shape);

   type Circle is new Shape with null record;
   procedure Draw (Self : Circle; Scale : Float);
end Precision_Overriding_Overload_Clean;
