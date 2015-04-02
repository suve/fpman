program fpman;

{$INCLUDE defines.inc}

uses
   SysUtils, Unix,
   descriptions, parser, troff;

Var
   InputLine, InputStr : AnsiString;
   Desc : TFunctionDesc;
   
   TmpName : AnsiString;
   TmpFile : Text;

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
   
   TmpName := GetTempFileName('', 'fpman-');
   Assign(TmpFile, TmpName);
   
   {$I-} Rewrite(TmpFile); {$I+}
   If(IOResult() <> 0) then begin
      Writeln(stderr, 'fpman: unable to write to temporary file: ',TmpName);
      Halt(1)
   end;
   
   OutputTroff(Desc, TmpFile);
   Close(TmpFile);
   
   fpExecLP('man', [TmpName])
end.
