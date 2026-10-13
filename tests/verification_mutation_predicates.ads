--  What a predicate does not say, and where it is not known. Each claim
--  marked in the body is false for some value the subprogram can be given,
--  or rests on a predicate that nothing establishes there: none of them is
--  to be proved.
package Verification_Mutation_Predicates with SPARK_Mode => On is

   type Field is (F_A, F_B, F_C);
   type State is (S_Valid, S_Invalid);

   type Cursor is record
      St    : State := S_Invalid;
      First : Natural := 0;
      Last  : Natural := 0;
   end record;

   type Cursors is array (Field) of Cursor;

   function Chain (C : Cursors) return Boolean is
     ((if C (F_B).St = S_Valid then C (F_A).St = S_Valid)
      and then (if C (F_C).St = S_Valid then C (F_B).St = S_Valid));

   function Extents (C : Cursors; Limit : Natural) return Boolean is
     (for all F in Field =>
        (if C (F).St = S_Valid
         then C (F).First <= C (F).Last and then C (F).Last <= Limit));

   function Whole (Limit : Natural; C : Cursors) return Boolean is
     (Limit <= 1000 and then Chain (C) and then Extents (C, Limit));

   type Context is record
      Limit : Natural := 0;
      Cur   : Cursors;
   end record with
     Dynamic_Predicate => Whole (Context.Limit, Context.Cur);

   subtype Short_Context is Context with
     Dynamic_Predicate => Short_Context.Limit <= 10;

   function Valid (Ctx : Context; F : Field) return Boolean is
     (Ctx.Cur (F).St = S_Valid);

   type Meter is record
      Step : Integer := 1;
   end record with
     Dynamic_Predicate => Ratio (Meter) > 0 and then Meter.Step /= 0;

   function Ratio (M : Meter) return Integer is (100 / M.Step);

   procedure Scramble (Ctx : in out Context) with SPARK_Mode => Off;
   procedure Renew (Ctx : in out Context);

   procedure Wrong_Way (Lower : Context) with Pre => Valid (Lower, F_A);
   procedure Stronger (Strict : Context);
   procedure Stronger_Subtype (Brief : Short_Context);
   procedure Other_Object (Known, Other : Context)
     with Pre => Valid (Known, F_C);
   procedure Out_Parameter (Made : out Context);
   procedure Component_Written (Edited : in out Context; Step : Natural)
     with Pre => Edited.Limit <= 500 and then Step <= 5000;
   procedure Other_Component_Written (Tied : in out Context)
     with Pre => Valid (Tied, F_A);
   procedure Element_Written (Moved : in out Context; Where : Field)
     with Pre => Valid (Moved, F_C);
   procedure Object_Written (Replaced : in out Context; Source : Context)
     with Pre => Valid (Replaced, F_C);
   procedure After_Callee (Passed : in out Context)
     with Pre => Valid (Passed, F_C);
   procedure After_Other_Code (Loose : in out Context)
     with SPARK_Mode => Off;
   procedure In_Other_Code (Free : Context) with SPARK_Mode => Off;

end Verification_Mutation_Predicates;
