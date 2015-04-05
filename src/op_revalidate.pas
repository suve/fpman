unit op_revalidate;

{$INCLUDE defines.inc}

interface

Procedure Operation_Revalidate();


implementation

uses
   SysUtils,
   conf, dynarray, db;


Procedure Operation_Revalidate();
Type
   TIDList = specialize GenericDynArray<sInt>;
Var
   IDlist : TIDList;
   rset : TResultSet;
   Idx : sInt;
   
   ConfDir, FileName : AnsiString;
begin
   rset.Create();
   If(Not FindPage('', rset)) then begin
      Writeln(stderr, 'fpman: failed to fetch list of pages from database');
      Writeln(stderr, 'fpman: aborting revalidation');
      
      db.Quit();
      Halt(1)
   end;
   
   IDlist.Create();
   ConfDir := GetConfPath() + 'pages/';
   For Idx := 0 to (rset.Count - 1) do begin
      FileName := LowerCase(rset[Idx].Package_) + '/' + LowerCase(rset[Idx].Unit_) + '/' + LowerCase(rset[Idx].Page) + '.man';
      If(FileExists(ConfDir + FileName)) then Continue;
      
      Writeln(stderr, 'fpman: manpage for ', rset[Idx].Package_, '.', rset[Idx].Unit_, '.', rset[Idx].Page, ' is missing');
      IDlist.Push(rset[Idx].ID)
   end;
   
   If(IDlist.Count = 0) then begin
      Writeln(stderr, 'fpman: revalidation complete, all pages present');
      db.Quit();
      Halt(0)
   end;
   
   IDlist.Trim();
   If(Not db.DeletePages(IDlist.arr)) then begin
      Writeln('fpman: failed to delete dead page entries from database');
      Idx := 1
   end else begin
      Writeln('fpman: ',IDlist.Count,' dead page entries deleted');
      Idx := 0
   end;
   
   db.Quit();
   Halt(Idx)
end;

end.
