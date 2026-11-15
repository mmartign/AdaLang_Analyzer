--  The bounds of a value that is no object: a string literal and a
--  catenation that starts with one, given to a formal of an unconstrained
--  String subtype, have the first value of the index subtype for lower
--  bound (RM 4.2(11), 4.5.3(6)); a component of a record has the bounds of
--  its own constrained subtype. GNATprove 16.1.0 proves every check here.
package Verification_Literal_Bounds with SPARK_Mode is

   subtype Text is String
     with Predicate => Text'First = 1 and Text'Last >= 0;
   subtype Short_Text is Text with Predicate => Short_Text'Last <= 5;

   subtype Line_Index is Positive range 1 .. 8;
   subtype Line_Text is String (Line_Index);

   type Message is record
      Data : String (Line_Index);
      Line : Line_Text;
   end record;

   procedure Take (X : Text) with Global => null;
   procedure Take_Short (X : Short_Text) with Global => null;

   procedure Log (Description : String)
     with Global => null, Pre => Description'First = 1;
   procedure Log_Three (Description : String)
     with Global => null, Pre => Description'Length = 3;
   procedure Need_Line (S : String)
     with Global => null, Pre => S'First = 1 and S'Last = 8;

   procedure Run (S : String; M : Message)
     with Global => null, Pre => S'Length <= 80;

end Verification_Literal_Bounds;
