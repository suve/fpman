unit op_import;

{$INCLUDE defines.inc}

interface

Procedure Operation_Import();


implementation

uses
   SysUtils, Unix,
   conf, options, descriptions, parser, db, troff;

Var
   InputLine, InputStr : AnsiString;
   Desc : TFunctionDesc;
   
   CacheDir : AnsiString;
   
   TmpName : AnsiString;
   TmpFile : Text;

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

Function ImportFile(Const FilePath:AnsiString):sInt;
begin
   InputStr := '';
   Assign(TmpFile, FilePath);
   
   {$I-} Reset(TmpFile); {$I+}
   If(IOResult() <> 0) then begin
      Writeln(stderr,'fpman: unable to read file: ',TmpName);
      Exit(-1)
   end;
   
   While(Not Eof(TmpFile)) do begin
      Readln(TmpFile, InputLine);
      InputStr += InputLine + #10
   end;
   Close(TmpFile);
   
   ResetDesc(Desc);
   ParseFunctionHTML(InputStr, Desc);
   
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
   
   If(Not db.AddPage(Desc)) then begin
      Writeln(stderr, 'fpman: failed to add page for ',Desc.Package_,'.',Desc.Unit_,'.',Desc.Name,' to sqlite database');
      Exit(-1)
   end;
   
   Exit(+1)
end;

Procedure ImportDirectory(Const Directory:AnsiString; Var SuccPages, SkipPages, FailPages : sInt);
Var
   Search : TSearchRec;
   Ext, PathOnly : AnsiString;
begin
   PathOnly := ExtractFilePath(Directory);
   If(RightStr(PathOnly, 1) <> '/') then PathOnly += '/';
   
   If(FindFirst(ModeArg, faDirectory, Search) = 0) then Repeat
      If((Search.Name = '.') or (Search.Name = '..')) then Continue;
      
      If((Search.Attr and faDirectory) = faDirectory) then begin
         ImportDirectory(PathOnly + '*', SuccPages, SkipPages, FailPages);
         Continue
      end;
      
      // Ignore non-html files
      Ext := LowerCase(ExtractFileExt(Search.Name));
      If(Ext <> '.html') then Continue;
      
      // Ignore unit index files
      Ext := LowerCase(LeftStr(Search.Name, 6));
      If((Ext = 'index.') or (Ext = 'index-')) then Continue;
      
      // Ignore identifier index files (e.g. index of class methods)
      Ext := LowerCase(RightStr(Search.Name, 7));
      If((Ext[1] = '-') and (Ext[2] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'])) then Continue;
      
      // Ignore operators
      If(LowerCase(LeftStr(Search.Name, 3)) = 'op-') then begin
         Writeln(stderr, 'fpman: ',PathOnly + Search.Name,' describes an operator, skipping');
         SkipPages += 1;
         Continue
      end;
      
      Case(ImportFile(PathOnly + Search.Name)) of
         +1: begin
            Writeln(stderr, 'fpman: successfully imported manpage for ',Desc.Package_,'.',Desc.Unit_,'.',Desc.Name);
            SuccPages += 1
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
   SuccPages, SkipPages, FailPages : sInt;
begin
   SuccPages := 0;
   SkipPages := 0;
   FailPages := 0;
   
   If(DirectoryExists(ModeArg)) then begin
      If(RightStr(ModeArg, 1) <> '/') then ModeArg += '/';
      ModeArg += '*'
   end;
   ImportDirectory(ModeArg, SuccPages, SkipPages, FailPages);
   
   If(SuccPages > 0) then begin
      Write(stderr, 'fpman: import finished, ',SuccPages,' pages imported');
      If(FailPages > 0) then Write(stderr, ', ',FailPages,' pages failed');
      If(SkipPages > 0) then Write(stderr, ', ',SkipPages,' pages skipped');
      Writeln(stderr);
      
      Halt(0)
   end;
   
   If(FailPages = 0) then begin
      If(SkipPages > 0)
         then Writeln(stderr, 'fpman: import finished, ',SkipPages,' pages skipped')
         else Writeln(stderr, 'fpman: import finished, no pages found');
      
      Halt(0)
   end;
   
   Write(stderr, 'fpman: import finished, failed to import ',FailPages,' pages');
   If(SkipPages > 0) then Write(stderr, ', ', SkipPages,' pages skipped');
   Writeln(stderr);
   
   Writeln(stderr, 'fpman: import failed');
   Halt(1)
end;

end.
