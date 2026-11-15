--  verification_literal_bounds with values whose bounds do not give what
--  is asked: a literal longer than the subtype allows, a catenation that
--  starts with an object or with a null literal, one of the wrong length
--  and a component with other bounds, each in a subprogram of its own.
--  GNATprove 16.1.0 proves none of the checks.
package Verification_Mutation_Literal_Bounds with SPARK_Mode is

   subtype Text is String
     with Predicate => Text'First = 1 and Text'Last >= 0;
   subtype Short_Text is Text with Predicate => Short_Text'Last <= 5;

   type Message is record
      Data : String (2 .. 9);
   end record;

   procedure Take_Short (X : Short_Text) with Global => null;

   procedure Log (Description : String)
     with Global => null, Pre => Description'First = 1;
   procedure Log_Three (Description : String)
     with Global => null, Pre => Description'Length = 3;
   procedure Need_Line (S : String)
     with Global => null, Pre => S'First = 1 and S'Last = 8;

   procedure Too_Long with Global => null;
   procedure Object_First (S : String)
     with Global => null, Pre => S'Length <= 80;
   procedure Null_First (S : String) with Global => null;
   procedure Wrong_Length with Global => null;
   procedure Other_Bounds (M : Message) with Global => null;

end Verification_Mutation_Literal_Bounds;
