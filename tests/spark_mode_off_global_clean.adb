procedure Spark_Mode_Off_Global_Clean
  with SPARK_Mode => Off
is
   --  The enclosing procedure carries SPARK_Mode => Off, not Activate
   --  itself. Activate's Global and Depends contracts are therefore
   --  unenforceable assumptions, not properties the implementation must be
   --  checked against: SPARK_Mode is inherited from the nearest enclosing
   --  scope when a declaration has no aspect of its own, so a contract
   --  that looks wrong against this body's actual reads and writes must
   --  not be reported.
   State : Boolean := False;

   procedure Activate (Flag : Boolean)
     with Global  => null,
          Depends => (null => Flag)
   is
   begin
      State := Flag;
   end Activate;

begin
   Activate (True);
end Spark_Mode_Off_Global_Clean;
