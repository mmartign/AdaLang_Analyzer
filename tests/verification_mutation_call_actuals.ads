--  What a call does not leave known of the objects it is given, nor of
--  those it can reach. Each claim marked below is false, or rests on
--  nothing the analysis may rely on: none of them is to be proved.
with System;

package Verification_Mutation_Call_Actuals is

   subtype Small is Integer range 0 .. 100;

   type Table is array (Small) of Integer;

   type Counter is record
      Count : Small;
      Step  : Small;
   end record;

   procedure External
     with Import, Convention => C, External_Name => "verification_external";

   --  It writes where it is told to.
   procedure Fill (Where : System.Address)
     with Import, Convention => C, External_Name => "verification_fill";

   Shared : Integer := 7;

   package Shapes is
      type Root is tagged null record;
      procedure Fill (Shape : Root; X : out Integer);
      type Hollow is new Root with null record;
      overriding procedure Fill (Shape : Hollow; X : out Integer);
      procedure Through_Class (Shape : Root'Class; R : out Integer);
   end Shapes;

   package Plain is
      procedure Give (X : out Small);
      procedure Never (X : out Integer);
      function Take (X : out Integer) return Boolean;
      procedure Run (Action : not null access procedure);
      procedure After_Body (T : Table; R : out Integer);
      procedure After_Never (R : out Integer);
      procedure After_Function (R : out Integer);
      procedure Component (C : Counter; T : Table; R : out Integer);
      procedure Outside_Object (R : out Integer);
      procedure With_Local_Code (R : out Integer);
      procedure Through_Address (R : out Integer);
      procedure Widened_Past (N : Natural; T : Table; R : out Integer);
   end Plain;

   --  Instantiated outside SPARK code: it is not SPARK code.
   generic
      Limit : Small;
   package Loose is
      procedure First (X : out Small);
      procedure After_First (T : Table; R : out Integer);
   end Loose;

   package Kept with SPARK_Mode => On is
      procedure Bump (X : in out Small);
      procedure After_In_Out (R : out Integer);
      procedure Unset_In_Out (T : Table; R : out Integer);
      procedure Component_Half (C : Counter; R : out Integer);
   end Kept;

end Verification_Mutation_Call_Actuals;
