program fpman;

{$INCLUDE defines.inc}

uses
   SysUtils, Unix,
   descriptions, parser, troff, db, conf, options;

Var
   InputLine, InputStr : AnsiString;
   Desc : TFunctionDesc;
   
   StoredInCache:Boolean;
   CacheDir : AnsiString;
   
   TmpName : AnsiString;
   TmpFile : Text;

Function CreateCacheDir():Boolean;
begin
   If(Desc.Package_ <> '')
      then CacheDir += LowerCase(Desc.Package_) + '/'
      else CacheDir += 'unknown/';
   
   If(Desc.Unit_ <> '')
      then CacheDir += LowerCase(Desc.Unit_) + '/'
      else CacheDir += 'unknown/';
   
   If(Not ForceDirectories(GetConfPath() + CacheDir)) then begin
      CacheDir := '~/.suve/fpman/' + CacheDir;
      Exit(False)
   end;
   
   TmpName := GetConfPath() + CacheDir + LowerCase(Desc.Name) + '.man';
   Exit(True)
end;

Function OutputToFile():Boolean;
begin
   Assign(TmpFile, TmpName);
   
   {$I-} Rewrite(TmpFile); {$I+}
   If(IOResult() <> 0) then Exit(False);
   
   OutputTroff(Desc, TmpFile);
   Close(TmpFile);
   
   Exit(True)
end;

Procedure Operation_Import();
begin
   InputStr := '';
   Assign(TmpFile, ModeArg);
   
   {$I-} Reset(TmpFile); {$I+}
   If(IOResult() <> 0) then begin
      Writeln(stderr,'fpman: unable to read file: ',TmpName);
      db.Quit();
      Halt(1)
   end;
   
   While(Not Eof(TmpFile)) do begin
      Readln(TmpFile, InputLine);
      InputStr += InputLine + #10
   end;
   Close(TmpFile);
   
   ParseFunctionHTML(InputStr, Desc);
   
   If(Not CreateCacheDir()) then begin
      Writeln(stderr, 'fpman: failed to create cache directory ', CacheDir);
      StoredInCache := False
   end else
   If(Not OutputToFile()) then begin
      Writeln(stderr, 'fpman: failed to write cache file ', CacheDir + LowerCase(Desc.Name) + '.man');
      StoredInCache := False
   end else
      StoredInCache := True;
   
   If(Not StoredInCache) then begin
      TmpName := GetTempFileName('', 'fpman-');
      If(Not OutputToFile()) then begin
         Writeln(stderr, 'fpman: failed to write temporary file ',TmpName);
         db.Quit();
         Halt(1)
      end
   end else begin
      If(Desc.Package_ <> '')
         then Desc.Package_ := LowerCase(Desc.Package_)
         else Desc.Package_ := 'unknown';
         
      If(Desc.Unit_ <> '')
         then Desc.Unit_ := LowerCase(Desc.Unit_)
         else Desc.Unit_ := 'unknown';
      
      db.AddPage(Desc)
   end;
end;

Procedure Operation_Search();
Var
   DoQuit : Boolean;
   rset : TResultSet;
   Idx : sInt;
begin
   If(Not db.FindPage(ParamStr(1), rset)) then begin
      DoQuit := True
   end else
   If(rset.numRows <= 0) then begin
      Writeln(stderr, 'fpman: no entry found for "', ParamStr(1), '"');
      
      If(Not NumberOfPages(Idx)) then Writeln(stderr, 'fpman: failed to check number of pages in database')
      else If(Idx < 1) then Writeln(stderr, 'fpman: database seems to be empty, consider running fpman --import');
      
      DoQuit := True
   end else
   If(rset.numRows > 1) then begin
      Writeln(stderr, 'fpman: multiple entries found for "', ParamStr(1), '":');
      For Idx := 0 to (rset.numRows - 1) do
         Writeln(stderr,
            'fpman: ',(Idx+1),': ',
            rset.Rows[Idx].Package_, '.',
            rset.Rows[Idx].Unit_, '.',
            rset.Rows[Idx].Page
         );
      DoQuit := True
   end else begin
      TmpName :=
         LowerCase(rset.Rows[0].Package_) + '/' +
         LowerCase(rset.Rows[0].Unit_) + '/' +
         LowerCase(rset.Rows[0].Page) + '.man'
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
   
   If(DoQuit) then begin
      db.Quit();
      Halt(1)
   end;
end;

// fpman.main()
begin
   If(ParamCount() = 0) then begin
      Write(Usage());
      Halt(0)
   end;
   
   ParseArgs();
   
   If(Not db.Init()) then Halt(1);
   If(Not db.CreateTables()) then Halt(1);
   
   Case(Mode) of
      MODE_PAGE: Operation_Search();
      MODE_IMPORT: Operation_Import();
   end;
   
   db.Quit();
   fpExecLP('man', [TmpName])
end.
