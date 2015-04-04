program fpman;

{$INCLUDE defines.inc}

uses
   SysUtils, Unix,
   descriptions, parser, troff, db, conf, options, dynarray;

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
   
   OutputTroff(TmpFile, Desc, ModeArg);
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
   ConfDir := GetConfPath();
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


Procedure Operation_Purge();
Type
   TDirList = specialize GenericDynArray<AnsiString>;
Var
   DirList : TDirList;
   Search : TSearchRec;
   ConfDir : AnsiString;
begin
   DirList.Create();
   
   DirList.Push('-rfv');
   ConfDir := GetConfPath();
   
   If(FindFirst(GetConfPath() + '*', faDirectory, Search) = 0) then Repeat
      If((Search.Name = '.') or (Search.Name = '..')) then Continue;
      If((Search.Attr and faDirectory) = 0) then Continue;
      
      DirList.Push(ConfDir + Search.Name + '/')
   Until(FindNext(Search) <> 0);
   FindClose(Search);
   
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

Procedure Operation_Search();
Var
   DoQuit : Boolean;
   rset : TResultSet;
   Idx : sInt;
begin
   rset.Create();
   If(Not db.FindPage(ModeArg, rset)) then begin
      Writeln(stderr, 'fpman: failed to search in database');
      DoQuit := True
   end else
   If(rset.Count <= 0) then begin
      Writeln(stderr, 'fpman: no entry found for "', ModeArg, '"');
      
      If(Not NumberOfPages(Idx)) then Writeln(stderr, 'fpman: failed to check number of pages in database')
      else If(Idx < 1) then Writeln(stderr, 'fpman: database seems to be empty, consider running fpman --import');
      
      DoQuit := True
   end else
   If(rset.Count > 1) then begin
      Writeln(stderr, 'fpman: multiple entries found for "', ModeArg, '":');
      For Idx := 0 to (rset.Count - 1) do
         Writeln(stderr,
            'fpman: ',(Idx+1),': ',
            rset[Idx].Package_, '.',
            rset[Idx].Unit_, '.',
            rset[Idx].Page
         );
      DoQuit := True
   end else begin
      TmpName :=
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
   
   If(Not db.Init()) then begin
      Writeln(stderr, 'fpman: failed to open/create fpman.sqlite');
      Halt(1)
   end;
   If(Not db.CreateTables()) then begin
      Writeln(stderr, 'fpman: failed to create tables');
      db.Quit();
      Halt(1)
   end;
   
   Case(Mode) of
      MODE_PAGE: Operation_Search();
      MODE_IMPORT: Operation_Import();
      MODE_PURGE: Operation_Purge();
      MODE_REVALIDATE: Operation_Revalidate();
   end;
   
   db.Quit();
   fpExecLP('man', [TmpName]);
   
   Writeln('fpman: failed to execute man');
   Halt(1)
end.
