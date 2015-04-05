unit op_search;

{$INCLUDE defines.inc}

interface

Procedure Operation_Search();


implementation

uses
   SysUtils, Unix,
   conf, options, db;


Procedure print_rset(Var rset:TResultSet);
Var
   Idx : sInt;
begin
   For Idx := 0 to (rset.Count - 1) do
      Writeln(stderr,
         'fpman: ',(Idx+1),': ',
         rset[Idx].Package_, '.',
         rset[Idx].Unit_, '.',
         rset[Idx].Page
      )
end;


Procedure Operation_Search();
Var
   TmpName : AnsiString;
   DoQuit : Boolean;
   rset : TResultSet;
   Pages : sInt;
begin
   rset.Create();
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
      
         If(Not NumberOfPages(Pages)) then Writeln(stderr, 'fpman: failed to check number of pages in database')
         else If(Pages < 1) then Writeln(stderr, 'fpman: database seems to be empty, consider running fpman --import')
      end else begin
         Writeln(stderr, 'fpman: ', rset.Count, ' similarly named pages found');
         print_rset(rset)
      end;
      
      DoQuit := True
   end else
   If(rset.Count > 1) then begin
      Writeln(stderr, 'fpman: multiple entries found for "', ModeArg, '":');
      print_rset(rset);
      DoQuit := True
   end else begin
      TmpName := 'pages/' + 
         LowerCase(rset[0].Package_) + '/' +
         LowerCase(rset[0].Unit_) + '/' +
         LowerCase(rset[0].Page) + '.man'
      ;
     
     
      If(Not FileExists(GetConfPath() + TmpName)) then begin
         Writeln(stderr, 'fpman: file ~/.suve/fpman/', TmpName, ' not found or is not readable');
         Writeln(stderr, 'fpman: you may want to run fpman --revalidate');
         DoQuit := True
      end else begin
         TmpName := GetConfPath() + TmpName;
         DoQuit := False
      end
   end;
   
   db.Quit();
   if(DoQuit) then Halt(1);
   
   fpExecLP('man', [TmpName]);
   
   Writeln(stderr, 'fpman: failed to execute man');
   Halt(1)
end;

end.
