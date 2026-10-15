--  FP-120: the value of a whole object and a component of that object with
--  the object's own name were one symbol. The key of the value of an
--  object, or of a part of it, has the object itself for its component,
--  and the symbol of a key was named by the text of its component: an
--  object X and a component X gave "X" twice. A record that is the
--  argument of a function stood for the integer in its component X, so
--  that two records equal in that component were one value, and a
--  function of each gave one result.
package Verification_FP120_Shared_Name with SPARK_Mode => On is

   type T is record
      X : Integer;
      Y : Integer;
   end record;

   type Pair is record
      Left  : T;
      Right : T;
   end record;

   function Get_Y (V : T) return Integer with Global => null;

   procedure Inner_Object (X : T);

   procedure Needs (A, B : T) with Pre => Get_Y (A) = Get_Y (B);
   procedure Two_Parts (X : Pair);

   type D (K : Natural := 0) is record
      X : Boolean;
   end record;

   procedure Constrained_After_Call (V : in out D);

end Verification_FP120_Shared_Name;
