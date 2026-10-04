with Ada.Text_IO;

package Precision_Naming is
   type my_type is range 1 .. 2;
   type MyType is range 1 .. 2;
   type My_Type2 is range 1 .. 2;
   type MY_TYPE is range 1 .. 2;
   type T_Index is range 1 .. 2;
   type Index_T is range 1 .. 2;
   subtype Small_T is Index_T range 1 .. 1;
   type Colour is (red, Green, BLUE, Dark_Blue, E_Dark);

   type Ref is access all Integer;
   type P_Ref is access all Integer;
   type Ref_A is access all Integer;
   type Ref_Ref_A is access Ref_A;
   type Handler is access procedure;
   type F_Handler is access procedure;

   type Shape is tagged null record;
   type Shape_Class_Ref is access all Shape'Class;
   type CP_Shape is access all Shape'Class;
   type T_Hidden is private;
   type Later;
   type Later is record
      Next : Ref;
   end record;

   task type Worker;
   task type J_Worker;
   protected type Guard is
      procedure Bump;
   private
      Count : Integer := 0;
   end Guard;

   Limit : constant Integer := 1;
   C_Limit : constant Integer := 1;
   Limit_C : constant Integer := 1;
   MAX_VALUE : constant := 2;
   Failure : exception;
   E_Failure : exception;
   BAD_THING : exception;
   counter : Integer := 0;
   IO_Count : Integer := 0;
   T_Counter : Integer := 0;
   Pointer : Ref := null;

   procedure Run (Target : in Ref; Count : in Integer);
   function Crimson return Colour renames red;
   package IO renames Ada.Text_IO;
   package IO_R renames Ada.Text_IO;
private
   type T_Hidden is range 1 .. 2;
end Precision_Naming;
