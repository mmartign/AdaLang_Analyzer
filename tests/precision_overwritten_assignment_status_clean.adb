--  Overwritten_Assignment, Dead_Store: the status a call of an imported
--  function returns, stored and not looked at, is how Ada calls it for its
--  effect (utilada's Util.Processes, simple_components' bindings).

with Interfaces.C; use Interfaces.C;

procedure Precision_Overwritten_Assignment_Status_Clean (A, B : int) is
   function Close (Fd : int) return int
     with Import, Convention => C, External_Name => "close";
   Result : int;
begin
   Result := Close (A);
   Result := Close (B);
end Precision_Overwritten_Assignment_Status_Clean;
