package body Verification_Formal_Contracts
  with SPARK_Mode
is
   function Upto_3 (X : Integer; Amount : Natural) return Integer
   is (if Amount > 0 then X else 0);

   function Upto_9 (Y : Integer; By : Natural) return Integer
   is (if By > 0 then Y else 0);

   function Free (X : Integer; Amount : Natural) return Integer
   is (if Amount > 0 then X else 0);

   function Swapped (Amount : Integer; X : Natural) return Integer
   is (if X > 0 then Amount else 0);

   function Over (X : Integer; Amount : Natural) return Integer
   is (if Amount > 0 then X else 0);

   function Over (X : Boolean; Amount : Natural) return Integer
   is (if X then Integer (Amount mod 2) else 0);

   procedure Act (V : in out Integer; N : Natural) is
   begin
      V := (if N > 0 then 1 else 0);
   end Act;

   package body Through_Plain is
      function Two (V : Integer) return Integer is (Plain (V, 2));
      function Named (V : Integer) return Integer is (Plain (N => 2, V => V));
      function Guarded (V : Integer; K : Natural) return Integer
      is (if K <= 2 then Plain (V, K) else 0);
   end Through_Plain;

   package body Through_Mixed is
      function Five (V : Integer) return Integer is (Mixed (V, 5));
   end Through_Mixed;

   package body Through_Cross is
      function Any (Value : Integer) return Integer is (Cross (Value, 2));
   end Through_Cross;

   package body Through_Picked is
      function Zero (V : Boolean) return Integer is (Picked (V, 0));
   end Through_Picked;

   package body Through_Step is
      procedure One (V : in out Integer) is
      begin
         Step (V, 1);
      end One;

      procedure After (V : in out Integer; K : Natural) is
      begin
         Step (V, K + 1);
      end After;
   end Through_Step;

   package body Bounded is
      function F (X : Integer; Amount : Natural) return Integer
      is (if Amount > 0 then X else 0);
   end Bounded;

   package body Through_Twice is
      function Two (V : Integer) return Integer is (Twice (V, 2));
   end Through_Twice;

   package body Outer is
      function Run (V : Integer) return Integer is (Rot (V, Steps));
   end Outer;

   package On_9 is new Through_Plain (Upto_9);
   package On_Renamed is new Through_Plain (Renamed_3);
   package On_Completed is new Through_Plain (Completed);

   package Mixed_Free is new Through_Mixed (Free);
   package Mixed_9 is new Through_Mixed (Upto_9);

   package On_Swapped is new Through_Cross (Swapped);

   package On_Over is new Through_Picked (Over);

   package On_Act is new Through_Step (Act);

   package Bounded_9 is new Bounded (9);
   package Bounded_3 is new Bounded (3);
   package Twice_9 is new Through_Twice (Bounded_9.F);
   package Twice_3 is new Through_Twice (Bounded_3.F);

   package Outer_3 is new Outer (Upto_3);
   package Outer_9 is new Outer (Upto_9);
   function Run_3_2 is new Outer_3.Run (2);
   function Run_9_2 is new Outer_9.Run (2);
   function Run_9_9 is new Outer_9.Run (9);

end Verification_Formal_Contracts;
