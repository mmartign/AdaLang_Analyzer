--  What a call leaves known of the objects it is given, and of those it is
--  not given.
--
--  An in out actual that was initialized is initialized after the call.
--  An out actual is initialized after it where the callee writes its
--  parameter on every path that returns: as the statements of its body
--  show, or, for a callee that is SPARK code, as SPARK asks of it. After a
--  call of SPARK code a scalar actual is within the subtype of the
--  parameter. A scalar component of a record that is read in SPARK code is
--  within the subtype it is declared with. A generic unit that sets no
--  SPARK_Mode is SPARK code where every instantiation of it is. A callee
--  declared outside a subprogram that declares no code of its own, and
--  gives no access value or address away, leaves the objects of that
--  subprogram as they were, whatever else it does.
package Verification_Call_Actuals is

   subtype Small is Integer range 0 .. 100;

   type Table is array (Small) of Integer;

   type Counter is record
      Count : Small;
      Step  : Small;
   end record;

   --  Nothing is known of what this does: no body, no Global aspect.
   procedure External
     with Import, Convention => C, External_Name => "verification_external";

   --  It writes what it is given an access value to.
   procedure Ask (Answer : access Boolean)
     with Import, Convention => C, External_Name => "verification_ask";

   --  Ordinary Ada.
   package Plain is
      procedure Give (X : out Small);
      procedure Bump (X : in out Small);
      procedure After_Body (R : out Integer);
      procedure After_In_Out (R : out Integer);
      procedure Widened (N : Natural; T : Table; R : out Integer);
      procedure Through_Access (R : out Integer);
   end Plain;

   --  It has the SPARK_Mode of where it is instantiated: in Kept only.
   generic
      Limit : Small;
   package Bounded is
      procedure First (X : out Small);
      procedure After_First (T : Table; R : out Integer);
   end Bounded;

   package Kept with SPARK_Mode => On is
      procedure Give (X : out Small);
      procedure Bump (X : in out Small);
      procedure Reset (C : in out Counter);
      procedure After_Out (T : Table; R : out Integer);
      procedure After_In_Out (T : Table; R : out Integer);
      procedure After_External (R : out Integer);
      procedure Component (C : Counter; T : Table; R : out Integer);
      procedure Component_After_Call
        (C : in out Counter; T : Table; R : out Integer);
      procedure Through_Instance (T : Table; R : out Integer);
   end Kept;

end Verification_Call_Actuals;
