--  FP-164: a call through an access-to-subprogram object named with a
--  package prefix ("API.Gen_Buffers (1, Id)", OpenGLAda's loaded entry
--  points) has out parameters too: Id is written by the call, not read, and
--  the name of a formal in a named association is not read either.

procedure Verification_FP164_Access_Call_Prefix (R : out Integer) is
   package API is
      type Gen is access procedure (Count : Integer; Id : out Integer);
      Gen_Buffers : Gen;
   end API;

   procedure Create (Id : out Integer) is
   begin
      API.Gen_Buffers (1, Id);
   end Create;

   procedure Create_Named (Id : out Integer) is
   begin
      API.Gen_Buffers (Count => 1, Id => Id);
   end Create_Named;

   A, B : Integer;
begin
   Create (A);
   Create_Named (B);
   R := A + B;
end Verification_FP164_Access_Call_Prefix;
