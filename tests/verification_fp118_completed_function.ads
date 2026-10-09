--  FP-118: a function declared in the visible part and completed by an
--  expression function in the private part has two sets of formals, those
--  of the declaration and those of the completion. A call written before
--  the completion names the declaration, and the expression of the
--  completion names its own formals: translated with the formals of the
--  declaration bound, the expression read each formal as an object nothing
--  was bound to, the same one at every call. What a contract said of the
--  function for one object then held for every object.
package Verification_FP118_Completed_Function with SPARK_Mode => On is

   type Context is record
      Ready : Boolean;
      Count : Natural;
   end record;

   function Checked (C : Context) return Boolean;

   function Good (C : Context) return Boolean;

   function Low (N : Integer) return Boolean;

   function Scaled (N : Integer; By : Integer := 2) return Boolean;

   procedure Need (C : Context) with Pre => Good (C);

   procedure Need_Low (N : Integer) with Pre => Low (N);

   procedure Need_Single (N : Integer) with Pre => Scaled (N, 1);

   --  Nothing is known of Other.
   procedure Another_Object (Known, Other : Context)
     with Pre => Good (Known);

   procedure Same_Object (Known, Other : Context)
     with Pre => Good (Known);

   procedure Another_Number (Known_N, Other_N : Integer)
     with Pre => Low (Known_N);

   procedure Same_Number (Known_N, Other_N : Integer)
     with Pre => Low (Known_N);

   --  Scaled (Doubled) is Scaled (Doubled, 2): below 20, not below 10.
   procedure Defaulted (Doubled : Integer) with Pre => Scaled (Doubled);

private

   function Good (C : Context) return Boolean is (Checked (C));

   function Low (N : Integer) return Boolean is (N < 10);

   function Scaled (N : Integer; By : Integer := 2) return Boolean is
     (N < 10 * By);

end Verification_FP118_Completed_Function;
