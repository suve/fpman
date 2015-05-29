unit op_purge;

{$INCLUDE defines.inc}

interface

Procedure Operation_Purge();


implementation

uses
   SysUtils, Unix,
   conf, db, options, utils;


Procedure Purge_All(Var DirList:TDirList);
begin
   DirList.Push(GetConfPath() + 'pages/');
   
   If(Not PurgeTables()) then begin
      Writeln(stderr, 'fpman: failed to purge sqlite database tables');
      Writeln(stderr, 'fpman: fpman.sqlite will be removed');
      
      db.Quit();
      DirList.Push(GetConfPath() + 'fpman.sqlite')
   end
end;

Procedure Purge_Section(Var DirList:TDirList);
Var
   PackName, UnitName: AnsiString;
   
   Idx: sInt;
   PackList: PDirList;
   PossibleDir: AnsiString;
begin
   If(Not ParseSection(ModeArg, PackName, UnitName)) then begin
      db.Quit();
      Halt(1)
   end;
   If(Not db.DeletePages(PackName, UnitName)) then begin
      Writeln(stderr, 'fpman: failed to delete pages from database');
      db.Quit();
      Halt(1)
   end;
   
   PackName := LowerCase(PackName);
   UnitName := LowerCase(UnitName);
   If(PackName <> '') then begin
      If(UnitName <> '')
         then DirList.Push(GetConfPath() + 'pages/' + PackName + '/' + UnitName + '/')
         else DirList.Push(GetConfPath() + 'pages/' + PackName + '/')
   end else begin
      PackList := GetDirListing(GetConfPath() + 'pages/', DIRLIST_DIRECTORIES);
      
      For Idx := 0 to (PackList^.Count - 1) do begin
         PossibleDir := GetConfPath() + 'pages/' + PackList^[Idx] + '/' + UnitName;
         If(DirectoryExists(PossibleDir)) then DirList.Push(PossibleDir)
      end;
      
      Dispose(PackList, Destroy())
   end
end;

Procedure Operation_Purge();
Var
   DirList : TDirList;
begin
   DirList.Create();
   DirList.Push('-rfv');
   
   If(ModeArg = '')
      then Purge_All(DirList)
      else Purge_Section(DirList);
   
   DirList.Trim();
   fpExecLP('rm',DirList.Arr);
   
   Writeln(stderr, 'fpman: failed to execute rm');
   Halt(1)
end;

end.
