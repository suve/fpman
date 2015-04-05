unit op_purge;

{$INCLUDE defines.inc}

interface

Procedure Operation_Purge();


implementation

uses
   SysUtils, Unix,
   conf, dynarray, db;


Procedure Operation_Purge();
Type
   TDirList = specialize GenericDynArray<AnsiString>;
Var
   DirList : TDirList;
   ConfDir : AnsiString;
begin
   DirList.Create();
   DirList.Push('-rfv');
   
   ConfDir := GetConfPath();
   DirList.Push(ConfDir + 'pages/');
   
   If(Not PurgeTables()) then begin
      Writeln(stderr, 'fpman: failed to purge sqlite database tables');
      Writeln(stderr, 'fpman: fpman.sqlite will be removed');
      
      db.Quit();
      DirList.Push(ConfDir + 'fpman.sqlite')
   end;
   
   DirList.Trim();
   fpExecLP('rm',DirList.Arr);
   
   Writeln(stderr, 'fpman: failed to execute rm');
   Halt(1)
end;

end.
