--  Precision regression for Global_Contract_Mismatch (FP-181, libgfxinit,
--  tokeneer, sparknacl): a Global aspect that names a state abstraction
--  allows the body to touch the constituents the Refined_State gives it,
--  as the state's mode allows; a body with a Refined_Global is held to
--  that; an Output global may be read after the body writes it; a
--  constant whose value depends on no variable is no global at all; a
--  renaming stands for the object it renames.
procedure Precision_Global_Contract_Mismatch_Refined_State_Clean
  with SPARK_Mode
is
   package Outer with Abstract_State => State, Initializes => State is
      procedure Touch with Global => (In_Out => State);
   end Outer;

   package body Outer with Refined_State => (State => (Count, Panel_State))
   is
      Count : Integer := 0;
      Alias : Integer renames Count;

      package Panel with Abstract_State => (Panel_State with Part_Of => State)
      is
         procedure Static_Init with Global => (Output => Panel_State);
         procedure Setup with Global => (In_Out => Panel_State);
      end Panel;

      package body Panel with Refined_State => (Panel_State => (A, B))
      is
         type Arr is array (1 .. 3) of Integer;
         A : Arr;
         B : Arr;

         Lookup : constant Arr := (1, 2, 3);

         --  The Global of the declaration, constituents written and one
         --  read after its write.
         procedure Static_Init is
         begin
            A := (others => 0);
            B := A;
         end Static_Init;

         --  Held to the Refined_Global.
         procedure Setup
         with Refined_Global => (In_Out => (A, B))
         is
         begin
            A (1) := A (1) + Lookup (2);
            B (2) := B (2) + 1;
         end Setup;
      end Panel;

      --  A constituent through two states (Count, and A and B through
      --  Panel_State), and a call whose Global names the inner state.
      procedure Touch is
      begin
         Count := Count + 1;
         Alias := Alias + 1;
         Panel.Setup;
      end Touch;
   begin
      Panel.Static_Init;
   end Outer;
begin
   Outer.Touch;
end Precision_Global_Contract_Mismatch_Refined_State_Clean;
