unit parser;

{$INCLUDE defines.inc}


interface
   uses descriptions;

Procedure ParseFunctionHTML(HTML:AnsiString;Out Func:TFunctionDesc);


implementation
   uses SysUtils, StrUtils, dynarray, utils;

Procedure TagToBold(Const OpenTag, CloseTag:AnsiString; Var Target:AnsiString);
Var
   StartPos, EndPos : sInt;
begin
   StartPos := Pos(OpenTag, Target);
   While(StartPos > 0) do begin
      Delete(Target, StartPos, Length(OpenTag));
      Insert('\fB', Target, StartPos);
      
      EndPos := PosEx(CloseTag, Target, StartPos);
      Delete(Target, EndPos, Length(CloseTag));
      Insert('\fR', Target, EndPos);
      
      StartPos := Pos(OpenTag, Target)
   end;
end;

Function HTML_to_troff(Const HTML:AnsiString; Const EmphasizeAnchors:Boolean = False):AnsiString;
Var
   StartPos, EndPos : sInt;
begin
   Result := Trim(HTML);
   Result := StringReplace(Result, '\', '\\', [rfReplaceAll]);
      
   Result := StringReplace(Result, '<var>',  '\fB', [rfReplaceAll]);
   Result := StringReplace(Result, '</var>', '\fR ', [rfReplaceAll]);
   
   Result := StringReplace(Result, '<em>',  '\fI', [rfReplaceAll]);
   Result := StringReplace(Result, '</em>', '\fR ', [rfReplaceAll]);
   
   TagToBold('<span class="kw">', '</span>', Result);
   TagToBold('<span class="file">', '</span>', Result);
   
   If(EmphasizeAnchors) then begin
      StartPos := Pos('<a href="../', Result);
      While(StartPos > 0) do begin
         EndPos := PosEx('>', Result, StartPos);
         Delete(Result, StartPos, EndPos - StartPos + 1);
         
         Insert('\fB', Result, StartPos);
         EndPos := PosEx('</a>', Result, StartPos);
         
         Delete(Result, EndPos, Length('</a>'));
         Insert('\fR', Result, EndPos); 
         
         StartPos := Pos('<a href="../', Result)
      end
   end;
   
   StartPos := Pos('<', Result);
   While(StartPos > 0) do begin
      EndPos := PosEx('>', Result, StartPos);
      Delete(Result, StartPos, EndPos - StartPos + 1);
      
      StartPos := Pos('<', Result)
   end;
   
   Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
   Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
   
   Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
   Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll]);
   
   Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
   
   // Remove all double spaces, and spaces before ,.;)] symbols
   StartPos := 1;
   EndPos := PosEx(' ', Result, StartPos);
   While(EndPos > 0) do begin
      If(EndPos = Length(Result)) then Break;
      
      If(Result[EndPos + 1] in [' ',',','.',')',';',']']) then begin
         Delete(Result, EndPos, 1);
         StartPos := EndPos
      end else
         StartPos := EndPos + 1;
      
      EndPos := PosEx(' ', Result, StartPos)
   end
end;

Procedure ParseLocation(Var Func:TFunctionDesc);
Var
   P : sInt;
begin
   Func.Unit_ := StringReplace(Func.Unit_, '''', '', [rfReplaceAll]);
   Func.Unit_ := Trim(Func.Unit_);
   
   P := Pos('#', Func.Package_);
   Delete(Func.Package_, 1, P);
   
   P := Pos('<', Func.Package_);
   Delete(Func.Package_, P, Length(Func.Package_))
end;

Procedure ParseParagraphs(Var Text:AnsiString);
Var
   Source, dlist, Line : AnsiString;
   ListIdx : sInt;
begin
   Source := Trim(Text);
   Text := '';
   
   While(Source <> '') do begin
      If(Copy(Source, 1, Length('<p>')) = '<p>') then begin
         Delete(Source, 1, Length('<p>'));
         DeleteUntil(Source, '</p>', @Line);
         
         Text += HTML_to_troff(Line, TRUE) + #10#10
      end else
      If(Copy(Source, 1, Length('<dl>')) = '<dl>') then begin
         Delete(Source, 1, Length('<dl>'));
         DeleteUntil(Source, '</dl>', @dlist);
         
         While(DeleteUntil(dlist, '<dt>')) do begin
            DeleteUntil(dlist, '</dt>', @Line);
            Text += '.TP' + #10 + '.B ' + HTML_to_troff(Line) + #10;
            
            DeleteUntil(dlist, '<dd>');
            DeleteUntil(dlist, '</dd>', @Line);
            Text += HTML_to_troff(Line) + #10
         end;
         Text += '.TP 0' + #10
      end else
      If(Copy(Source, 1, Length('<ol>')) = '<ol>') then begin
         Delete(Source, 1, Length('<ol>'));
         DeleteUntil(Source, '</ol>', @dlist);
         
         Text += #10;
         ListIdx := 0;
         While(DeleteUntil(dlist, '<li>')) do begin
            DeleteUntil(dlist, '</li>', @Line);
            ListIdx += 1;
            
            Text += '\fB' + IntToStr(ListIdx) + '.\fR ' + HTML_to_troff(Line) + #10#10
         end
      end else
      If(Copy(Source, 1, Length('<table class="remark"')) = '<table class="remark"') then begin
         DeleteUntil(Source, '<td>');
         DeleteUntil(Source, '</td>', @Line);
         
         Text += '\fIRemark:\fR ' + HTML_to_troff(Line) + #10#10;
         DeleteUntil(Source, '</table>')
      end else
         Source := '';
      
      Source := TrimLeft(Source)
   end;
   
   If(RightStr(Text, Length('.TP 0' + #10)) = '.TP 0' + #10) then
      Delete(Text, Length(Text) - Length('.TP 0' + #10), Length('.TP 0' + #10))
end;

Procedure Declaration_Routine(Const DeclType:AnsiString; Var Func:TFunctionDesc; Var Source:AnsiString);
Var
   DeclName, Symb, ReturnType : AnsiString;
   
   Params : Array[0..31] of AnsiString;
   ParamNum, Idx : sInt;
   
   PaQual, PaName, PaType : AnsiString;
begin
   DeleteUntil(Source, '<span class="sym">', @DeclName);
   DeclName := Trim(DeclName);
   
   DeleteUntil(Source, '</span>', @Symb);
   Symb := Trim(Symb);
   
   ParamNum := 0;
   
   If(Symb = '.') then begin
      DeleteUntil(Source, '<span class="sym">', @Symb);
      
      DeclName += '.' + Symb;
      
      DeleteUntil(Source, '</span>', @Symb);
      Symb := Trim(Symb)
   end;
   
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
      DeleteUntil(Source, '<span class="sym">', @ReturnType);
      ReturnType := HTML_to_troff(ReturnType);
      
      DeleteUntil(Source, '</span>', @Symb);
      Symb := Trim(Symb)
   end;
   
   If(Symb <> ';') then Exit(); // fuck it
   If(Func.Declaration <> '') then Func.Declaration += #10#10;
   
   Func.Declaration += DeclType + ' ' + '\fB' + HTML_to_troff(DeclName) + '\fR';
   
   If(ParamNum > 0) then begin
      Func.Declaration += '(';
      
      For Idx := 0 to (ParamNum - 1) do
         Func.Declaration += Params[Idx];
      
      Delete(Func.Declaration, Length(Func.Declaration) - 1, 2);
      Func.Declaration += ')'
   end;
   
   If(ReturnType <> '') then Func.Declaration += ':' + HTML_to_troff(ReturnType);
   Func.Declaration += ';'
end;

Procedure Declaration_Method(Const Visibility:AnsiString; Var Func:TFunctionDesc; Var Source:AnsiString);
Var
   DeclKw : AnsiString;
begin
   DeleteUntil(Source, '<span class="kw">');
   DeleteUntil(Source, '</span>', @DeclKw);
   
   Declaration_Routine(Visibility + ' ' + DeclKw, Func, Source);
end;

Procedure Declaration_Type(Var Func:TFunctionDesc; Var Source:AnsiString);
Type
   TMemberRow = record
      Visibility, Prefix, Name, Type_, Suffix, RW, Comment : AnsiString;
      Length : sInt;
   end;
   
   TMemberList = specialize GenericDynArray<TMemberRow>;
Var
   DeclType, DeclName, Fragment, MemberString, Visibility : AnsiString;
   
   Member : TMemberRow;
   Idx, LongestMember : sInt;
   MemberList:TMemberList;
   
   CommentPos, NextMemberPos: sInt;
begin
   DeleteUntil(Source, '<span class="sym">', @DeclName);
   DeclName := Trim(DeclName);
   
   (* After name of type, '<span class="sym"> = </span>' always follows.
    * 
    * Complex types (records, objects, classes) will have '<span class="kw">STRUCT_TYPE</span>' after that.
    * Pointers will have '<span class="sym">^</span>'.
    * Type aliases will have neither, but the test will match the closing '<span class="sym">;</span>'.
    * 
    * Checking span class is an easy way to distinguish between those.
    *)
   DeleteUntil(Source, '</span>');
   DeleteUntil(Source, '<span class="', @DeclType);
   If(LeftStr(Source, 3) = 'sym') then begin
      DeleteUntil(Source, '>');
      
      If(Source[1] = '^') then begin
         DeleteUntil(Source, '</span>');
         DeleteUntil(Source, '<span class="sym">', @DeclType);
         
         Func.Declaration := '\fBtype\fR ' + DeclName + ' = \fB^\fR' + HTML_to_troff(DeclType) + ';'
      end else begin
         
         Func.Declaration := '\fBtype\fR ' + DeclName + ' = ' + HTML_to_troff(DeclType) + ';'
      end;
      
      Exit()
   end;
   
   DeleteUntil(Source, '>');
   DeleteUntil(Source, '</span>', @DeclType);
   DeclType := Trim(DeclType);
   
   (* Pascal has this wonderful thing where you can declare two types that are functionally identical,
    * but distinct for purposes of type checking, RTTI, and so on.
    *
    * These are done by typing in a 'type XXX = type YYY;' declaration.
    *
    * These types will have '<span class="kw">type</span>' after the '<span class="sym"> = </span>',
    * thus they won't match the test above for '<span class="sym">'.
    *
    * Thus, we have to check if DeclType isn't "type". If this is the case, 
    * we extract the name of the original type and quickly GTFO.
    *)
   If(DeclType = 'type') then begin
      DeleteUntil(Source, '<span class="sym">;', @DeclType);
      Func.Declaration := '\fBtype\fR ' + DeclName + ' = \fBtype\fR ' + HTML_to_troff(DeclType) + ';';
      
      Exit()
   end;
   
   // Check if there's an opening parenthesis after decltype.
   // If yes, then this is a child object/class and we gotta parse inheritance.
   If(LeftStr(Source, Length('<span class="sym">(')) = '<span class="sym">(') then begin
      Delete(Source, 1, Length('<span class="sym">('));
      DeleteUntil(Source, '<span class="sym">)</span>', @Fragment);
      
      DeclType += ' (' + HTML_to_troff(Fragment) + ')'
   end;
   
   Visibility := '';
   LongestMember := 0;
   MemberList.Create();
   
   While(DeleteUntil(Source, '<span class="code">&nbsp;&nbsp;', @Fragment)) do begin
      If(DeleteUntil(Fragment, '<span class="code"><span class="kw">')) then begin
         DeleteUntil(Fragment, '</span></span>', @Visibility)
      end;
      
      Member.Visibility := Visibility;
      
      If(LeftStr(Source, Length('<span class="kw">')) = '<span class="kw">') then begin
         Delete(Source, 1, Length('<span class="kw">'));
         DeleteUntil(Source, '</span>', @Fragment);
         
         Member.Prefix := HTML_to_troff(Fragment)
      end;
      
      DeleteUntil(Source, '<span class="sym">', @Member.Name);
      
      If(Source[1] = ':') then begin
         DeleteUntil(Source, '</span>');
         DeleteUntil(Source, '<span class="sym">', @Member.Type_);
         
         Member.Type_ := HTML_to_troff(Member.Type_)
      end else
         Member.Type_ := '';
      
      DeleteUntil(Source, '</span>');
      
      Member.Suffix := '';
      While(LeftStr(Source, Length('<span class="kw">')) = '<span class="kw">') do begin
         Delete(Source, 1, Length('<span class="kw">'));
         DeleteUntil(Source, '</span>', @Fragment);
         
         If(Member.Suffix <> '') then Member.Suffix += '; ';
         Member.Suffix += HTML_to_troff(Fragment);
         
         DeleteUntil(Source, '<span class="sym">;</span>');
      end;
      
      If(LeftStr(Source, Length('  [')) = '  [') then begin
         Delete(Source, 1, Length('  ['));
         DeleteUntil(Source, ']', @Member.RW);
      end else
         Member.RW := '';
      
      CommentPos := Pos('<p class="cmt">', Source);
      NextMemberPos := Pos('<span class="code">&nbsp;&nbsp;', Source);
      If((CommentPos > 0) AND ((NextMemberPos = 0) OR (CommentPos < NextMemberPos))) then begin
         DeleteUntil(Source, '<p class="cmt">');
         DeleteUntil(Source, '</p>', @Member.Comment)
      end else
         Member.Comment := '';
      
      Member.Name := HTML_to_troff(Member.Name);
      Member.Type_ := HTML_to_troff(Member.Type_);
      
      Member.Length := Length(Member.Name);
      If(Member.Prefix <> '') then Member.Length += Length(Member.Prefix) + 1; // 1 = ' '
      If(Member.Type_ <> '') then Member.Length += Length(Member.Type_) + 2; // 2 = ': '
      If(Member.Suffix <> '') then Member.Length += Length(Member.Suffix) + 2; // 1 = ' ;'
      If(Member.RW <> '') then Member.Length += Length(Member.RW) + 3; // 3 = ' []'
      
      If(Member.Length > LongestMember) then LongestMember := Member.Length;
      
      MemberList.Push(Member)
   end;
   
   Func.Declaration := '\fBtype\fR ' + DeclName + ' = \fB' + DeclType + '\fR';
   Visibility := '';
   
   For Idx := 0 to (MemberList.Count - 1) do begin
      Member := MemberList[Idx];
      
      If(Member.Visibility <> Visibility) then begin
         Visibility := Member.Visibility;
         MemberString := #10 + '.br' + #10 + '\fB' + Visibility + '\fR' + #10#32#32
      end else
         MemberString := #10#32#32;
      
      If(Member.Prefix <> '') then MemberString += '\fB' + Member.Prefix + '\fR ';
      
      MemberString += Member.Name;
      
      If(Member.Type_ <> '') then MemberString += ': \fB' + Member.Type_ + '\fR';
      
      MemberString += ';';
      
      If(Member.Suffix <> '') then begin
         MemberString += ' ';
         
         While(DeleteUntil(Member.Suffix, '; ', @Fragment)) do 
            MemberString += '\fB' + Fragment + '\fR; ';
         
         MemberString += '\fB' + Member.Suffix + '\fR;'
      end;
      
      If(Member.RW <> '') then MemberString += ' [' + Member.RW + ']';
      
      If(Member.Comment <> '') then begin
         MemberString += StringOfChar(' ', LongestMember - Member.Length);
         MemberString += ' // ' + HTML_to_troff(Member.Comment)
      end;
      
      Func.Declaration += MemberString
   end;
   
   Func.Declaration += #10'.br'#10'\fBend\fR;'
end; 

Procedure Declaration_Var(Const DeclPref:AnsiString; Var Func:TFunctionDesc; Var Source:AnsiString);
Var
   DeclName, DeclType, DeclVal : AnsiString;
   IsPtr : Boolean;
begin
   DeleteUntil(Source, '<span class="sym">', @DeclName);
   DeclName := Trim(DeclName);
   
   If(Source[1] = ':') then begin
      DeleteUntil(Source, '</span>');
      DeleteUntil(Source, '<span class="sym">', @DeclType);
      DeclType := HTML_to_troff(DeclType)
   end else
      DeclType := '';
   
   If(Source[1] = '[') then begin
      DeleteUntil(Source, '</span>');
      DeleteUntil(Source, '<span class="sym">]', @DeclType);
      
      DeleteUntil(DeclType, '<span class="sym">.</span><span class="sym">.</span>', @DeclVal);
      DeclType := HTML_to_troff(DeclVal) + ' .. ' + HTML_to_troff(DeclType);
      
      DeleteUntil(Source, '<span class="kw">of</span>');
      DeleteUntil(Source, '<span class="sym">', @DeclVal);
      
      DeclType := '\fBarray[\fR' + DeclType + '\fB] of \fR' + HTML_to_troff(DeclVal)
   end;
   
   If(Source[1] = '=') then begin
      DeleteUntil(Source, '</span>');
      DeleteUntil(Source, '<span class="sym">', @DeclVal);
      DeclVal := HTML_to_troff(DeclVal);
      
      If(DeclVal = '') then begin
         IsPtr := (Source[1] = '@');
         DeleteUntil(Source, '</span>');
         
         DeleteUntil(Source, '<span class="sym">', @DeclVal);
         DeclVal := HTML_to_troff(DeclVal);
         
         If(IsPtr) then DeclVal := '\fB@\fR' + DeclVal
      end else
      If(DeclVal[1] = '''') then begin
         DeclVal := '''\fI' + Copy(DeclVal, 2, Length(DeclVal) - 2) + '\fR'''
      end
   end else
      DeclVal := '';
   
   Func.Declaration += '\fB' + DeclPref + '\fR ' + DeclName;
   If(DeclType <> '') then Func.Declaration += ': \fB' + DeclType + '\fR';
   If(DeclVal <> '') then Func.Declaration += ' = ' + DeclVal;
   Func.Declaration += ';'#10
end;

Procedure ParseDeclaration(Var Func:TFunctionDesc);
Var
   Source, DeclType : AnsiString;
begin
   Source := Func.Declaration;
   Func.Declaration := '';
   
   If(DeleteUntil(Source, 'Source position:')) then begin
      DeleteUntil(Source, ' line ', @Func.File_);
      DeleteUntil(Source, '</p>', @Func.Line_);
      
      Func.File_ := Trim(Func.File_);
      Func.Line_ := Trim(Func.Line_)
   end else begin
      Func.File_ := '';
      Func.Line_ := ''
   end;
   
   DeleteUntil(Source, '<table cellpadding="0" cellspacing="0">');
   While(DeleteUntil(Source, '<span class="kw">')) do begin
      DeleteUntil(Source, '</span>', @DeclType);
      DeclType := LowerCase(Trim(DeclType));
      
      Case(DeclType) of
         'strict':    Declaration_Method('strict'   , Func, Source); // strict private, yay
         'private':   Declaration_Method('private'  , Func, Source); 
         'protected': Declaration_Method('protected', Func, Source); 
         'public':    Declaration_Method('public'   , Func, Source); 
         'published': Declaration_Method('published', Func, Source); 
         
         'virtual': Func.Declaration += ' \fBvirtual\fR;';
         'abstract': Func.Declaration += ' \fBabstract\fR;';
         
         'procedure': Declaration_Routine('procedure', Func, Source);
         'function': Declaration_Routine('function', Func, Source);
         
         'const': Declaration_Var('const', Func, Source);
         'var': Declaration_Var('var', Func, Source);
         
         'type': Declaration_Type(Func, Source);
      end
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
      
      Func.SeeAlso += '.TP' + #10 + '.B ' + Name + #10 + HTML_to_troff(Desc) + #10
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

Procedure ParseName(Var Func:TFunctionDesc);
Var
   P : sInt;
begin
   P := Pos(' (', Func.Name);
   If(P = 0) then Exit();
   
   Func.Classifiers := Copy(Func.Name, P + 2, Length(Func.Name));
   Delete(Func.Classifiers, Length(Func.Classifiers), 1);
   
   Func.Name := LeftStr(Func.Name, P - 1)
end;

Procedure ParseFunctionHTML(HTML:AnsiString;Out Func:TFunctionDesc);
Var
   Section, Content : AnsiString;
   StillParsing : Boolean;
begin
   ResetDesc(Func);
   
   If(DeleteUntil(HTML, '<span class="bartitle">Reference for unit')) then begin
      DeleteUntil(HTML, '(', @Func.Unit_);
      DeleteUntil(HTML, ')', @Func.Package_)
   end else begin
      Func.Unit_ := '';
      Func.Package_ := ''
   end;
   
   DeleteUntil(HTML, '<h1>');
   DeleteUntil(HTML, '</h1>', @Func.Name);
   
   // Import skips some files, so we check the skip conditions here
   // This allows us to stop parsing early and save some time
   If(Trim(Func.Name) = '') then Exit();
   If(LowerCase(LeftStr(Func.Name, Length('operator '))) = 'operator ') then Exit();
   
   DeleteUntil(HTML, '<p>');
   DeleteUntil(HTML, '</p>', @Func.Summary);
   
   // Skip the paragraph with links to [Methods (By Name)] et cetera
   If((Func.Summary <> '') and (Func.Summary[1] = '[')) then begin
      DeleteUntil(HTML, '<p>');
      DeleteUntil(HTML, '</p>', @Func.Summary)
   end;
   
   Func.Summary := HTML_to_troff(Func.Summary);
   
   StillParsing := DeleteUntil(HTML, '<h2>');
   While(StillParsing) do begin
      DeleteUntil(HTML, '</h2>', @Section);
      
      If(Not DeleteUntil(HTML, '<h2>', @Content)) then begin
         DeleteUntil(HTML, '<hr>', @Content);
         StillParsing := False
      end;
      
      Section := LowerCase(Section);
      Case Section of
         'declaration': Func.Declaration := Content;
         'description': Func.Description := Content;
         'errors': Func.Errors := Content;
         'see also': Func.SeeAlso := Content
      end
   end;
   
   If(DeleteUntil(HTML, '<span class="footer">')) then begin
      DeleteUntil(HTML, '</span>', @Func.GeneratedOn);
      ParseGeneratedOn(Func)
   end else
      Func.GeneratedOn := '';
   
   ParseLocation(Func);
   ParseDeclaration(Func);
   
   ParseParagraphs(Func.Description);
   ParseParagraphs(Func.Errors);
   
   ParseName(Func);
   ParseSeeAlso(Func)
end;

end.
