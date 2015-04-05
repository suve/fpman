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
   
   StoredInCache:Boolean;
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
   
   Halt(0)
end;

end.
