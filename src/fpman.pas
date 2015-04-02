program fpman;

{$INCLUDE defines.inc}

uses
   SysUtils, Unix,
   descriptions, parser, troff;

Var
   InputLine, InputStr : AnsiString;
   Desc : TFunctionDesc;
   
   StoredInCache:Boolean;
   CacheDir : AnsiString;
   
   TmpName : AnsiString;
   TmpFile : Text;

Const
   HomeVar = {$IFDEF   LINUX} 'HOME';    {$ELSE}
             {$IFDEF WINDOWS} 'APPDATA'; {$ELSE}
             {$FATAL HomeVar must be set.} {$ENDIF} {$ENDIF}
             
   ConfDir = {$IFDEF   LINUX} '/.suve/fpman/'; {$ELSE}
             {$IFDEF WINDOWS} '\suve\fpman\';  {$ELSE}
             {$FATAL ConfDir must be set.} {$ENDIF} {$ENDIF}

Function GetConfPath():AnsiString;
begin
   Result := GetEnvironmentVariable(HomeVar) + ConfDir
end;

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

// fpman.main()
begin
   InputStr := '';
   
   If(ParamCount() = 0) then begin
      While(Not Eof(Input)) do begin
         Readln(Input, InputLine);
         InputStr += InputLine + #10
      end;
   end else begin
      TmpName := ParamStr(1);
      Assign(TmpFile, TmpName);
      
      {$I-} Reset(TmpFile); {$I+}
      If(IOResult() <> 0) then begin
         Writeln(stderr,'fpman: unable to read file: ',TmpName);
         Halt(1)
      end;
      
      While(Not Eof(TmpFile)) do begin
         Readln(TmpFile, InputLine);
         InputStr += InputLine + #10
      end;
      Close(TmpFile)
   end;
   
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
         Halt(1)
      end
   end;
   
   fpExecLP('man', [TmpName])
end.
