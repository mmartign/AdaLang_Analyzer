--  Outside SPARK code two parameters may be one array, and an array with
--  volatile components may change between two reads: what is known of the
--  elements of one is not known of the other, nor of the second read, nor
--  what is written to one.
package Verification_Mutation_Array_Aliases is
   type I64 is range -2 ** 63 .. 2 ** 63 - 1;
   type Index is range 0 .. 63;
   type Wides is array (Index) of I64;
   type Shared is array (Index) of I64 with Volatile_Components;
   subtype Small is I64 range 0 .. 100;

   procedure Alias (Xa : in out Wides; Ya : in out Wides; K : Index;
                    S : out Small)
     with Pre => (for all I in Index => Xa (I) in 0 .. 100);
   procedure Volatile (Vc : Shared; K : Index; S : out Small)
     with Pre => Vc (K) in 0 .. 100;
   procedure Alias_Store (Xb : in out Wides; Yb : in out Wides; K : Index;
                          S : out Small);
   --  An in parameter may be an object the loop writes by its own name: a
   --  loop does not keep what is known of it.
   G : Wides := (others => 0);
   procedure Global_Alias (Ga : Wides; S : out Small)
     with Pre => (for all I in Index => Ga (I) in 0 .. 100);
end Verification_Mutation_Array_Aliases;
