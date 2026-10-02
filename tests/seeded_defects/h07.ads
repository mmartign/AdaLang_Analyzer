with Ada.Finalization;
package H07 is
   type Rec is record
      A : Integer := 1;
      B : Integer := 1;
   end record;
   type Colour is (Red, Green, Blue);
   subtype Small is Integer range 0 .. 10;
   G : Integer := 5;
   type Ctrl is new Ada.Finalization.Controlled with null record;
   overriding procedure Finalize (Object : in out Ctrl);
   overriding procedure Initialize (Object : in out Ctrl);
   protected Guard is
      procedure Set (V : Integer);
      function Get return Integer;
   private
      Value : Integer := 5;
   end Guard;
   function Zero_G return Integer;
   type With_Default is record
      F : Integer := Zero_G;
   end record;
   procedure Takes_Small (X : Small);
   procedure Gives_Big (X : out Integer);
   procedure Two (R1, R2 : in out Rec; Sink : out Integer);
   procedure S01 (N : Integer; Sink : out Integer);
   procedure S02 (N : Integer; Sink : out Integer);
   procedure S03 (N : Integer; Sink : out Integer);
   procedure S04 (N : Integer; Sink : out Integer);
   procedure S05 (N : Integer; Sink : out Integer);
   procedure S06 (N : Integer; Sink : out Integer);
   procedure S07 (N : Integer; Sink : out Integer);
   procedure S08 (N : Integer; Sink : out Integer);
   procedure S09 (N : Integer; Sink : out Integer);
   procedure S10 (N : Integer; Sink : out Integer);
   procedure S11 (N : Integer; Sink : out Integer);
   procedure S12 (N : Integer; Sink : out Integer);
   procedure S13 (N : Integer; Sink : out Integer);
   procedure S14 (N : Integer; Sink : out Integer);
   procedure S15 (N : Integer; C : Colour; Sink : out Integer);
   procedure S16 (N : Integer; Sink : out Integer);
   procedure S17 (N : Integer; Sink : out Integer);
   procedure S18 (N : Integer; Sink : out Integer);
   procedure S19 (N : Integer; Sink : out Integer);
   procedure S20 (N : Integer; Sink : out Integer);
end H07;
