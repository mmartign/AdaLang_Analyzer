package body Verification_Mutation_Formal_Contracts
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

   function By_Pragma (X : Integer; Amount : Natural) return Integer
   is (if Amount > 0 then X else 0);

   function Prim (V : Root; N : Natural) return Integer
   is (Integer (N mod 2));

   function Plain_Pre (V : Integer; N : Natural) return Integer
   is (if N > 0 then V else 0);

   function Made (X : Integer; Amount : Natural) return Integer
   is (if Amount > 0 then X else 0);

   procedure Act (V : in out Integer; N : Natural) is
   begin
      V := (if N > 0 then 1 else 0);
   end Act;

   function Default (V : Integer; N : Natural) return Integer
   is (if N > 0 then V else 0);

   package body Through_Some is
      function Five (V : Integer) return Integer is (Some_Hold (V, 5));
      function Open (V : Integer; K : Natural) return Integer
      is (Some_Hold (V, K));
   end Through_Some;

   package body Through_Free is
      function Open (V : Integer; K : Natural) return Integer
      is (Free_Beside (V, K));
   end Through_Free;

   package body Through_Cross is
      function Open (K : Natural) return Integer is (Cross (0, K));
   end Through_Cross;

   package body Through_Picked is
      function Three (V : Boolean) return Integer is (Picked (V, 3));
   end Through_Picked;

   package body Through_Pragma is
      function Two (V : Integer) return Integer is (By_Other (V, 2));
   end Through_Pragma;

   package body Through_Class is
      function Two (V : T) return Integer is (By_Class (V, 2));
   end Through_Class;

   package body Through_Instance is
      function Two (V : Integer) return Integer is (By_Instance (V, 2));
   end Through_Instance;

   package body Bounded is
      function F (X : Integer; Amount : Natural) return Integer
      is (if Amount > 0 then X else 0);
   end Bounded;

   package body Through_Twice is
      function Five (V : Integer) return Integer is (Twice (V, 5));
   end Through_Twice;

   package body Through_Step is
      procedure Seven (V : in out Integer) is
      begin
         Step (V, 7);
      end Seven;
   end Through_Step;

   package body Outer is
      function Run (V : Integer) return Integer is (Rot (V, Steps));
      function Seven (V : Integer) return Integer is (Rot (V, 7));
   end Outer;

   package body Through_Default is
      function Two (V : Integer) return Integer is (Default (V, 2));
   end Through_Default;

   package Some_3 is new Through_Some (Upto_3);
   package Some_9 is new Through_Some (Upto_9);

   package Free_Free is new Through_Free (Free);
   package Free_9 is new Through_Free (Upto_9);

   package On_Swapped is new Through_Cross (Swapped);

   package On_Over is new Through_Picked (Over);

   package Pragma_9 is new Through_Pragma (Upto_9);
   package Pragma_1 is new Through_Pragma (By_Pragma);

   package Class_9 is new Through_Class (Integer, Plain_Pre);
   package Class_1 is new Through_Class (Root, Prim);

   function Made_1 is new Made (1);
   package Instance_9 is new Through_Instance (Upto_9);
   package Instance_1 is new Through_Instance (Made_1);

   package Bounded_9 is new Bounded (9);
   package Bounded_3 is new Bounded (3);
   package Twice_9 is new Through_Twice (Bounded_9.F);
   package Twice_3 is new Through_Twice (Bounded_3.F);

   package On_Act is new Through_Step (Act);

   package Outer_3 is new Outer (Upto_3);
   package Outer_9 is new Outer (Upto_9);
   function Run_3_9 is new Outer_3.Run (9);
   function Run_9_9 is new Outer_9.Run (9);

   package Default_Given is new Through_Default (Upto_9);
   package Default_Taken is new Through_Default;

end Verification_Mutation_Formal_Contracts;
