unit op_import;

{$INCLUDE defines.inc}

interface

Procedure Operation_Import();


implementation

uses
   SysUtils, Unix,
   dynarray,
   conf, options, descriptions, parser, db, troff, utils;

Type
   TDescArray = specialize GenericDynArray<TPageSummary>;

Var
   InputStr : AnsiString;
   
   Desc: TPageDescription;
   DescList: TDescArray;
   
   CacheDir : AnsiString;
   SuccPages, halfPages, SkipPages, FailPages : sInt;
   
   TmpName : AnsiString;
   TmpFile : Text;

Const
   IMPORT_STEP = 100;

Function CreateCacheDir():Boolean;
begin
   CacheDir := 'pages/';
   
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

Function OutputToFile(Const OriginalFile:AnsiString):Boolean;
begin
   Assign(TmpFile, TmpName);
   
   {$I-} Rewrite(TmpFile); {$I+}
   If(IOResult() <> 0) then Exit(False);
   
   OutputTroff(TmpFile, Desc, OriginalFile);
   Close(TmpFile);
   
   Exit(True)
end;

Function CopyToFile():Boolean;
begin
   Assign(TmpFile, TmpName);
   
   {$I-} Rewrite(TmpFile); {$I+}
   If(IOResult() <> 0) then Exit(False);
   
   Write(TmpFile, InputStr);
   Close(TmpFile);
   
   Exit(True)
end;

Function ImportFile_HTML(Const FilePath:AnsiString):sInt;
begin
   InputStr := '';
   If(Not GetFileContents(FilePath, InputStr)) then begin
      Writeln(stderr,'fpman: unable to read ',FilePath);
      Exit(-1)
   end;
   
   ParseFunctionHTML(InputStr, Desc, FilePath);
   
   If(Trim(Desc.Name) = '') then begin
      Writeln(stderr, 'fpman: failed to parse ',FilePath);
      Exit(-1)
   end;
   
   If(LowerCase(LeftStr(Desc.Name, Length('operator '))) = 'operator ') then begin
      Writeln(stderr, 'fpman: ',FilePath,' describes an operator, skipping');
      Exit(0)
   end;
   
   If(Not CreateCacheDir()) then begin
      Writeln(stderr, 'fpman: failed to create cache directory ', CacheDir);
      Exit(-1)
   end else
   If(Not OutputToFile(FilePath)) then begin
      Writeln(stderr, 'fpman: failed to write cache file ', CacheDir + LowerCase(Desc.Name) + '.man');
      Exit(-1)
   end;
   
   If(Desc.Package_ <> '')
      then Desc.Package_ := LowerCase(Desc.Package_)
      else Desc.Package_ := 'unknown';
      
   If(Desc.Unit_ <> '')
      then Desc.Unit_ := LowerCase(Desc.Unit_)
      else Desc.Unit_ := 'unknown';
   
   Exit(+1)
end;

Function ImportFile_MAN(Const FilePath:AnsiString):sInt;
Var
   ParseResult: sInt;
begin
   InputStr := '';
   If(Not GetFileContents(FilePath, InputStr)) then begin
      Writeln(stderr,'fpman: unable to read ',FilePath);
      Exit(-1)
   end;
   
   ParseResult := ParseTroff(InputStr, Desc);
   
   If(ParseResult = -1) then begin
      Writeln(stderr, 'fpman: failed to parse ',FilePath);
      Exit(-1)
   end else
   If(ParseResult = 0) then begin
      Writeln(stderr, 'fpman: ',FilePath,' does not seem to be an fpman manpage');
      Exit(0)
   end;
   
   If(Not CreateCacheDir()) then begin
      Writeln(stderr, 'fpman: failed to create cache directory ', CacheDir);
      Exit(-1)
   end else
   If(Not CopyToFile()) then begin
      Writeln(stderr, 'fpman: failed to write cache file ', CacheDir + LowerCase(Desc.Name) + '.man');
      Exit(-1)
   end;
   
   If(Desc.Package_ <> '')
      then Desc.Package_ := LowerCase(Desc.Package_)
      else Desc.Package_ := 'unknown';
      
   If(Desc.Unit_ <> '')
      then Desc.Unit_ := LowerCase(Desc.Unit_)
      else Desc.Unit_ := 'unknown';
   
   Exit(+1)
end;

Procedure ImportDirectory(Const Directory:AnsiString);
Type
   TParseFunc = Function(Const FilePath:AnsiString):sInt;
Var
   Search: TSearchRec;
   Ext, Temp, PathOnly: AnsiString;
   
   ParseFunc: TParseFunc;
begin
   PathOnly := ExtractFilePath(Directory);
   If(RightStr(PathOnly, 1) <> '/') then PathOnly += '/';
   
   If(FindFirst(Directory, faDirectory, Search) = 0) then Repeat
      If((Search.Name = '.') or (Search.Name = '..')) then Continue;
      
      If((Search.Attr and faDirectory) = faDirectory) then begin
         ImportDirectory(PathOnly + Search.Name + '/*');
         Continue
      end;
      
      // Ignore non-html and non-man files
      Ext := LowerCase(ExtractFileExt(Search.Name));
      If(Ext = '.html') then ParseFunc := @ImportFile_HTML
      else If(Ext = '.man') then ParseFunc := @ImportFile_MAN
      else Continue;
      
      // Ignore unit index files
      Temp := LowerCase(LeftStr(Search.Name, 6));
      If((Temp = 'index.') or (Temp = 'index-')) then Continue;
      
      // Ignore identifier index files (e.g. index of class methods)
      Temp := LowerCase(RightStr(Search.Name, 7));
      If((Temp[1] = '-') and (Temp[2] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'])) then Continue;
      
      // Ignore operators
      If(LowerCase(LeftStr(Search.Name, 3)) = 'op-') then begin
         Writeln(stderr, 'fpman: ',PathOnly + Search.Name,' describes an operator, skipping');
         SkipPages += 1;
         Continue
      end;
      
      Case(ParseFunc(PathOnly + Search.Name)) of
         +1: begin
            Writeln(stderr, 'fpman: parsed manpage for ',Desc.Package_,'.',Desc.Unit_,'.',Desc.Name);
            DescList.Push(Summarize(Desc));
            
            If(DescList.Count >= IMPORT_STEP) then begin
               If(db.AddMultiplePages(DescList.Ptr, DescList.Count)) then begin
                  Writeln(stderr, 'fpman: successfully added ',DescList.Count,' pages to database');
                  SuccPages += DescList.Count
               end else begin
                  Writeln(stderr, 'fpman: failed to add ',DescList.Count,' pages to database');
                  HalfPages += DescList.Count
               end;
               
               DescList.Purge()
            end
         end;
         
         0:
            SkipPages += 1;
         
         -1:
            FailPages += 1
      end
   Until(FindNext(Search) <> 0);
   FindClose(Search)
end;

Procedure Operation_Import();
Var
   StartTime, EndTime : Comp;
begin
   StartTime := TimeStampToMSecs(DateTimeToTimeStamp(Now()));
   SuccPages := 0; HalfPages := 0; SkipPages := 0; FailPages := 0;
   
   DescList.Create(IMPORT_STEP);
   
   If(Not EnsureUniquePageIndex()) then begin
      Writeln(stderr, 'fpman: failed to create unique page index');
      Writeln(stderr, 'fpman: aborting import');
      
      db.Quit();
      Halt(1)
   end;
   
   If(DirectoryExists(ModeArg)) then begin
      If(RightStr(ModeArg, 1) <> '/') then ModeArg += '/';
      ModeArg += '*'
   end;
   ImportDirectory(ModeArg);
   
   If(DescList.Count > 0) then begin
      If(db.AddMultiplePages(DescList.Ptr, DescList.Count)) then begin
         Writeln(stderr, 'fpman: successfully added ',DescList.Count,' pages to database');
         SuccPages += DescList.Count
      end else begin
         Writeln(stderr, 'fpman: failed to add ',DescList.Count,' pages to database');
         halfPages += DescList.Count
      end
   end;
   DescList.Destroy();
   
   EndTime := TimeStampToMSecs(DateTimeToTimeStamp(Now()));
   
   If(SuccPages > 0) or (halfPages > 0) then begin
      Write(stderr, 'fpman: import finished in ',TimeDiff(StartTime,EndTime),', ',SuccPages,' pages imported');
      If(halfPages > 0) then Write(stderr, ', ',halfPages,' pages outside database');
      If(FailPages > 0) then Write(stderr, ', ',FailPages,' pages failed');
      If(SkipPages > 0) then Write(stderr, ', ',SkipPages,' pages skipped');
      Writeln(stderr);
      
      Halt(0)
   end;
   
   If(FailPages = 0) then begin
      If(SkipPages > 0)
         then Write(stderr, 'fpman: import finished in ',TimeDiff(StartTime,EndTime),', ',SkipPages,' pages skipped')
         else Write(stderr, 'fpman: import finished in ',TimeDiff(StartTime,EndTime),', no pages found');
      
      Halt(0)
   end;
   
   Write(stderr, 'fpman: import finished in ',TimeDiff(StartTime,EndTime),', failed to import ',FailPages,' pages');
   If(SkipPages > 0) then Write(stderr, ', ', SkipPages,' pages skipped');
   Writeln(stderr);
   
   Writeln(stderr, 'fpman: import failed');
   Halt(1)
end;

end.
