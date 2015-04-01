program fpman;

{$INCLUDE defines.inc}

uses SysUtils, StrUtils, Unix; //, libcurl, sqlite3;

Type
   PFunctionDesc = ^TFunctionDesc;
   TFunctionDesc = record
      Name : AnsiString;
      Summary : AnsiString;
      Declaration : AnsiString;
      Description : AnsiString;
      Errors : AnsiString;
      SeeAlso : AnsiString;
      GeneratedOn : AnsiString;
   end;

Function DeleteUntil(Var Target:AnsiString; Const Limiter:AnsiString; Const StoreInto:PAnsiString = NIL):Boolean;
Var
   P:sInt;
begin
   P := Pos(Limiter, Target);
   If(P <= 0) then Exit(False);
   
   If(StoreInto <> NIL) then begin
      If(P > 1)
         then StoreInto^ := Copy(Target, 1, P-1)
         else StoreInto^ := ''
   end;
   Delete(Target, 1, P + Length(Limiter) - 1);
   
   Exit(True)
end;

Function HTML_to_troff(Const HTML:AnsiString):AnsiString;
Var
   StartPos, EndPos : sInt;
begin
   Result := Trim(HTML);
   Result := StringReplace(Result, '\', '\\', [rfReplaceAll]);
      
   Result := StringReplace(Result, '<var>',  '\fB', [rfReplaceAll]);
   Result := StringReplace(Result, '</var>', '\fR ', [rfReplaceAll]);
   
   Result := StringReplace(Result, '<em>',  '\fI', [rfReplaceAll]);
   Result := StringReplace(Result, '</em>', '\fR ', [rfReplaceAll]);
   
   Result := StringReplace(Result, ' .', '.', [rfReplaceAll]);
   Result := StringReplace(Result, ' ,', ',', [rfReplaceAll]);
   Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
   
   StartPos := Pos('<a href="../', Result);
   While(StartPos > 0) do begin
      EndPos := PosEx('>', Result, StartPos);
      Delete(Result, StartPos, EndPos - StartPos + 1);
      
      StartPos := PosEx('</a>', Result);
      Delete(Result, StartPos, Length('</a>'));
      
      StartPos := Pos('<a href="../', Result)
   end;
end;

Procedure ParseParagraphs(Var Text:AnsiString);
Var
   Source, Line : AnsiString;
begin
   Source := Trim(Text);
   Text := '';
   
   While(Source <> '') do begin
      If(Copy(Source, 1, Length('<p>')) = '<p>') then begin
         Delete(Source, 1, Length('<p>'));
         DeleteUntil(Source, '</p>', @Line);
         
         Text += HTML_to_troff(Line) + #10#10
      end else
      If(Copy(Source, 1, Length('<table class="remark"')) = '<table class="remark"') then begin
         DeleteUntil(Source, '<td>');
         DeleteUntil(Source, '</td>', @Line);
         
         Text += '\fIRemark:\fR ' + HTML_to_troff(Line) + #10#10;
         DeleteUntil(Source, '</table>')
      end else
         Source := '';
      
      Source := TrimLeft(Source)
   end
end;

Procedure ParseDeclaration(Var Func:TFunctionDesc);
Var
   Source, DeclType, DeclName : AnsiString;
   
   Symb, ReturnType : AnsiString;
   
   Params : Array[0..31] of AnsiString;
   ParamNum, Idx : sInt;
   
   PaQual, PaName, PaType : AnsiString;
begin
   Source := Func.Declaration;
   Func.Declaration := '';
   
   DeleteUntil(Source, '<table cellpadding="0" cellspacing="0">');
   While(DeleteUntil(Source, '<span class="kw">')) do begin
      DeleteUntil(Source, '</span>', @DeclType);
      
      DeleteUntil(Source, '<span class="sym">', @DeclName);
      DeclName := Trim(DeclName);
      
      DeleteUntil(Source, '</span>', @Symb);
      Symb := Trim(Symb);
      
      ParamNum := 0;
      If(Symb = '(') then begin
         While(DeleteUntil(Source, '<span class="code">')) do begin
            If(Copy(Source, 1, Length('&nbsp;&nbsp;')) <> '&nbsp;&nbsp;') then Break;
            Delete(Source, 1, Length('&nbsp;&nbsp;'));
            
            If(Copy(Source, 1, Length('<span class="kw">')) = '<span class="kw">') then begin
               Delete(Source, 1, Length('<span class="kw">'));
               
               DeleteUntil(Source, '</span>', @PaQual);
               PaQual := '\fB' + Trim(PaQual) + '\fR '
            end else begin
               PaQual := ''
            end;
            
            DeleteUntil(Source, '<span class="sym">: </span>', @PaName);
            DeleteUntil(Source, '</span>', @Symb);
            
            If(Copy(Symb, 1, 3) = '<a ') then DeleteUntil(Symb, '>');
            If(Not DeleteUntil(Symb, '<', @PaType)) then PaType := Symb;
            
            Params[ParamNum] := PaQual + PaName + ':' + PaType + '; ';
            ParamNum += 1
         end;
         
         If(DeleteUntil(Source, '<span class="sym">)</span>')) then begin
            DeleteUntil(Source, '<span class="sym">');
            DeleteUntil(Source, '</span>', @Symb);
            Symb := Trim(Symb)
         end else begin
            DeleteUntil(Source, '<span class="sym">):</span>');
            Symb := ':'
         end
      end;
      
      If(Symb = ':') then begin
         If(DeleteUntil(Source, '<a href="../')) then begin
            DeleteUntil(Source, '>');
            DeleteUntil(Source, '</a>', @ReturnType);
            
            DeleteUntil(Source, '<span class="sym">');
         end else begin
            DeleteUntil(Source, '<span class="sym">', @ReturnType);
            ReturnType := Copy(ReturnType, 1, Length(ReturnType) - Length('<span class="sym">'))
         end;
         
         DeleteUntil(Source, '</span>', @Symb);
         Symb := Trim(Symb);
      end;
      
      If(Symb <> ';') then Continue; // fuck it
      If(Func.Declaration <> '') then Func.Declaration += #10#10;
      
      Func.Declaration += DeclType + ' ' + '\fB' + DeclName + '\fR';
      
      If(ParamNum > 0) then begin
         Func.Declaration += '(';
         
         For Idx := 0 to (ParamNum - 1) do
            Func.Declaration += Params[Idx];
         
         Delete(Func.Declaration, Length(Func.Declaration) - 1, 2);
         Func.Declaration += ')'
      end;
      
      If(ReturnType <> '') then Func.Declaration += ':' + ReturnType;
      Func.Declaration += ';'
   end
end;

Procedure ParseSeeAlso(Var Func:TFunctionDesc);
Var
   Source, Name, Desc : AnsiString;
begin
   Source := Func.SeeAlso;
   Func.SeeAlso := '';
   
   While(DeleteUntil(Source, '<a href="../')) do begin
      DeleteUntil(Source, '>');
      DeleteUntil(Source, '</a>', @Name);
      
      DeleteUntil(Source, '<p class="cmt">');
      DeleteUntil(Source, '</p>', @Desc);
      
      Func.SeeAlso += '.TP' + #10 + '.B ' + Name + #10 + Desc + #10
   end
end;

Procedure ParseGeneratedOn(Var Func:TFunctionDesc);
Const
   MonthNames : Array[1..12] of ShortString = (
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
   );
Var
   Source, Year, Month, Day : AnsiString;
   Idx : sInt;
begin
   Source := Func.GeneratedOn;
   If(Not DeleteUntil(Source, 'Documentation generated on: ')) then Exit();
   
   DeleteUntil(Source, ' ', @Month);
   Month := LowerCase(Month);
   
   For Idx := 1 to 12 do
      If(Month = MonthNames[Idx]) then begin
         Month := IntToStr(Idx);
         If(Idx < 10) then Month := '0' + Month;
         
         Break
      end;
   
   DeleteUntil(Source, ' ', @Day);
   Year := Copy(Source, 1, 4);

   Func.GeneratedOn := Year + '-' + Month + '-' + Day
end;

Procedure ParseFunctionHTML(HTML:AnsiString;Var Func:TFunctionDesc);
Var
   P:sInt;
begin
   DeleteUntil(HTML, '<h1>');
   DeleteUntil(HTML, '</h1>', @Func.Name);
   
   DeleteUntil(HTML, '<p>');
   DeleteUntil(HTML, '</p>', @Func.Summary);
   
   DeleteUntil(HTML, '</h2>');
   DeleteUntil(HTML, '<h2>', @Func.Declaration);
   
   DeleteUntil(HTML, '</h2>');
   DeleteUntil(HTML, '<h2>', @Func.Description);
   
   DeleteUntil(HTML, '</h2>');
   DeleteUntil(HTML, '<h2>', @Func.Errors);
   
   DeleteUntil(HTML, '</h2>');
   DeleteUntil(HTML, '<h2>', @Func.SeeAlso);
   
   DeleteUntil(HTML, '<span class="footer">');
   DeleteUntil(HTML, '</span>', @Func.GeneratedOn);
   
   ParseDeclaration(Func);
   
   ParseParagraphs(Func.Description);
   ParseParagraphs(Func.Errors);
   
   ParseSeeAlso(Func);
   ParseGeneratedOn(Func)
end;

Procedure OutputTroff(Const Desc:TFunctionDesc; Var F:System.Text);
begin
   Writeln(F, '.\" file autogenerated by fpman');
   Writeln(F, '.TH "fpc-',LowerCase(Desc.Name),'" 3 "', Desc.GeneratedOn, '" "fpman" "Free Pascal Programmer''s Manual"');
   
   Writeln(F, '.SH NAME');
   Write(F, Desc.Name);
   If(Desc.Summary <> '') then Write(F, ' - ', Desc.Summary);
   Writeln(F);
   
   If(Desc.Declaration <> '') then begin
      Writeln(F,'.SH SUMMARY');
      Writeln(F, Desc.Declaration);
   end;
   
   Writeln(F, '.SH DESCRIPTION');
   Writeln(F, Desc.Description);
   
   Writeln(F, '.SH ERRORS');
   Writeln(F, Desc.Errors);
   
   If(Desc.SeeAlso <> '') then begin
      Writeln(F, '.SH SEE ALSO');
      Writeln(F, Desc.SeeAlso);
   end;
   
   Writeln(F, '.SH FPMAN');
   Write(F, 'manpage autogenerated by \fBfpman\fR from ');
   If(ParamCount > 0)
      then Write(F, '\fI', ExtractFileName(ParamStr(1)), '\fR')
      else Write(F, 'STDIN');
   Writeln(F, ' on ',FormatDateTime('yyyy-mm-dd, hh:nn:ss', Now()),'.'#10);
end;

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
   
   fpExecL('/bin/man', [TmpName])
end.
