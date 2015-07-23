unit op_list;

{$INCLUDE defines.inc}

interface

Procedure Operation_List();


implementation

uses
   SysUtils, Unix,
   conf, options, db, descriptions, troff, utils;


Procedure Operation_List();
Var
   TmpName, Content : AnsiString;
   Desc: TPageDescription;
   DoQuit : Boolean;
   rset : TResultSet;
   Idx : sInt;
begin
   rset.Create();
   DoQuit := False;
   
   If(Not db.FindPage(ModeArg, rset)) then begin
      Writeln(stderr, 'fpman: failed to search in database');
      DoQuit := True
   end else
   If(rset.Count <= 0) then begin
      Writeln(stderr, 'fpman: no entry found for "', ModeArg, '"');
      
      If(Not FindSimilarPages(ModeArg, rset)) then begin
         Writeln(stderr, 'fpman: failed to search for similarly named pages');
      end else
      If(rset.Count <= 0) then begin
         Writeln(stderr, 'fpman: no pages with similar names found');
      
         If(Not NumberOfPages(Idx)) then Writeln(stderr, 'fpman: failed to check number of pages in database')
         else If(Idx < 1) then Writeln(stderr, 'fpman: database seems to be empty, consider running fpman --import')
      end else begin
         Writeln(stderr, 'fpman: ', rset.Count, ' similarly named pages found');
         print_rset(rset)
      end;
      
      DoQuit := True
   end;
   
   db.Quit();
   if(DoQuit) then Halt(1);
   
   For Idx := 0 to (rset.Count - 1) do begin
      Writeln(stdout, rset[Idx].Package_ + '.' + rset[Idx].Unit_ + '.' + rset[Idx].Page);
      
      TmpName := 'pages/' + 
         LowerCase(rset[Idx].Package_) + '/' +
         LowerCase(rset[Idx].Unit_) + '/' +
         LowerCase(rset[Idx].Page) + '.man'
      ;
      
      If(Not GetFileContents(GetConfPath() + TmpName, Content)) then begin
         Writeln(stderr, 'fpman: file ~/.suve/fpman/', TmpName, ' not found or is not readable');
         Continue;
      end;
      
      Case(ParseTroff(Content, Desc)) of
         -1: Writeln(stderr, 'fpman: failed to parse manpage');
          0: Writeln(stderr, 'fpman: file ~/.suve/fpman/', TmpName, ' does not seem to be an fpman page');
         +1: Writeln(stdout, '  ', StripTroff(Desc.Summary));
      end
   end;
   
   Halt()
end;

end.
