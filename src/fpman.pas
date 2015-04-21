program fpman;

{$INCLUDE defines.inc}

uses
   SysUtils,
   db, options,
   op_import, op_purge, op_rebuild, op_revalidate, op_search;

Var
   dbWasCreated: Boolean;

// fpman.main()
begin
   If(ParamCount() = 0) then begin
      Write(Usage());
      Halt(0)
   end;
   
   ParseArgs();
   
   If(Not db.Init(@dbWasCreated)) then begin
      Writeln(stderr, 'fpman: failed to open/create fpman.sqlite');
      Halt(1)
   end;
   
   If(dbWasCreated) then
      If(Not db.CreateTables()) then begin
         Writeln(stderr, 'fpman: failed to create tables');
         db.Quit();
         Halt(1)
      end;
   
   Case(Mode) of
      MODE_PAGE: Operation_Search();
      MODE_IMPORT: Operation_Import();
      MODE_PURGE: Operation_Purge();
      MODE_REBUILD: Operation_Rebuild();
      MODE_REVALIDATE: Operation_Revalidate();
   end;
   
   db.Quit();
   
   Writeln(stderr, 'fpman: end of main() reached, should never happen');
   Halt(1)
end.
