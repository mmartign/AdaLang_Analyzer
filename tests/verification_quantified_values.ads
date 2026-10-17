--  Quantified expressions used as values inside the verified subset: in a
--  condition, an assignment, an initializer. Over a discrete range or an
--  array, a quantified expression evaluates its predicate for one value of
--  the loop parameter after another; the checks inside it are those of the
--  values the range may give the parameter, and a call in it is evaluated
--  where the expression is. Each assertion of Effectful_Predicate,
--  Stale_Element, Vacuous, Some_Found and Nested_Same_Name fails at run
--  time. The others hold.
package Verification_Quantified_Values is

   type Arr is array (1 .. 10) of Integer;

   Calls : Integer := 0;
   function Noisy (X : Integer) return Boolean;

   procedure Effectful_Predicate;
   procedure Stale_Element;
   procedure Vacuous (N : Natural) with Pre => N = 0;
   procedure Some_Found;
   procedure Nested_Same_Name;
   procedure Inside_Range (A : Arr; Last : Integer) with Pre => Last in 0 .. 10;
   procedure Declared_Value (A : Arr);

end Verification_Quantified_Values;
