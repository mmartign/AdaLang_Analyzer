--  The predicate of a subtype is known of a parameter of SPARK code when
--  the subprogram is entered, and of an object a callee that is SPARK code
--  was given to write when the call returns: the predicate is part of the
--  subtype, the caller's obligation in the first case and the callee's in
--  the second. It is taken part by part. Every claim marked in the body
--  holds; the ones that do not are in Verification_Mutation_Predicates.
package Verification_Predicates with SPARK_Mode => On is

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

   type Holder is record
      Inner : Context;
      Extra : Integer := 0;
   end record;

   function Valid (Ctx : Context; F : Field) return Boolean is
     (Ctx.Cur (F).St = S_Valid);

   function Get_A (Ctx : Context) return Natural with Pre => Valid (Ctx, F_A);

   procedure Set_C (Ctx : in out Context) with Post => Valid (Ctx, F_C);

   procedure At_Entry (Entered : Context; N : out Natural)
     with Pre => Valid (Entered, F_C);
   procedure Bounded (Sized : Context) with Pre => Valid (Sized, F_B);
   procedure No_Overflow (Wide : Context; N : out Natural)
     with Pre => Valid (Wide, F_B);
   procedure After_Call (Called : in out Context; N : out Natural);
   procedure Part_Given (Box : in out Holder; N : out Natural);
   procedure Both_Predicates (Brief : Short_Context);
   procedure In_Postcondition (Posted : in out Context)
     with Post => Get_A (Posted) = Get_A (Posted);

end Verification_Predicates;
