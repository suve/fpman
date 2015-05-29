unit utils;

{$INCLUDE defines.inc}


interface
   uses db, dynarray;

Type
   PDirList = ^TDirList;
   TDirList = specialize GenericDynArray<AnsiString>;

Const
   DIRLIST_FILES = 1;
   DIRLIST_DIRECTORIES = 2;
   DIRLIST_ALL = (DIRLIST_FILES or DIRLIST_DIRECTORIES);

Function DeleteUntil(Var Target:AnsiString; Const Limiter:AnsiString; Const StoreInto:PAnsiString = NIL):Boolean;
Function TimeDiff(Const StartTime, EndTime:Comp):AnsiString;

Function GetFileContents(Const FilePath:AnsiString; Out Content:AnsiString):Boolean;
Function GetDirListing(DirPath:AnsiString;Const Flags:sInt = DIRLIST_ALL):PDirList;

Function IdentifierIsValid(Const Ident: AnsiString):Boolean;
Function ParseSection(Sect:AnsiString;Out Package_, Unit_:AnsiString):Boolean;

Procedure print_rset(Var rset:TResultSet);


implementation
   uses SysUtils;


Function TimeDiff(Const StartTime, EndTime:Comp):AnsiString;
Var
   Diff : sInt;
begin
   Diff := Trunc(EndTime - StartTime);
   
   If(Diff < 1000) then begin
      WriteStr(Result, Diff,'ms');
      Exit()
   end;
   
   If(Diff < 60 * 1000) then begin
      WriteStr(Result, (Diff/1000):0:1,'s');
      Exit()
   end;
   
   If(Diff < 60 * 60 * 1000) then begin
      WriteStr(Result, (Diff div (60*1000)), 'm ', ((Diff div 1000) mod 60), 's');
      Exit()
   end;
   
   If(Diff < 24 * 60 * 60 * 1000) then begin
      WriteStr(Result, (Diff div (60*60*1000)), 'h ', ((Diff div (60*1000)) mod 60), 'm');
      Exit()
   end;
   
   WriteStr(Result, (Diff div (24*60*60*1000)), 'd ', ((Diff div (60*60*1000)) mod 24), 'h');
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


Function GetFileContents(Const FilePath:AnsiString; Out Content:AnsiString):Boolean;
Var
   Handle: Text;
   Line: AnsiString;
begin
   Assign(Handle, FilePath);
   {$I-} Reset(Handle); {$I+}
   If(IOResult() <> 0) then Exit(False);
   
   Content := '';
   While(Not eof(Handle)) do begin
      Readln(Handle, Line);
      Content += Line + #10
   end;
   
   Close(Handle);
   Exit(True)
end;


Function GetDirListing(DirPath:AnsiString;Const Flags:sInt = DIRLIST_ALL):PDirList;
Var
   Srch: TSearchRec;
begin
   DirPath := ExtractFileDir(DirPath);
   If(RightStr(DirPath, 1) <> '/') then DirPath += '/';
   DirPath += '*';
   
   New(Result, Create());
   
   If(FindFirst(DirPath, (faReadOnly or faDirectory), Srch) = 0) then repeat
      If((Srch.Name = '.') or (Srch.Name = '..')) then Continue;
      
      If((Srch.Attr and faDirectory) = faDirectory) then begin
         If((Flags and DIRLIST_DIRECTORIES) = 0) then Continue
      end else begin
         If((Flags and DIRLIST_FILES) = 0) then Continue
      end;
      
      Result^.Push(Srch.Name)
   Until(FindNext(Srch) <> 0);
   
   FindClose(Srch);
   Result^.Trim()
end;


Function IdentifierIsValid(Const Ident: AnsiString):Boolean;
Var
   P, L: sInt;
begin
   L := Length(Ident);
   If(L = 0) then Exit(False);
   
   For P:=1 to L do begin
      If Not ((Ident[P] in ['a'..'z']) or (Ident[P] in ['A'..'Z']) or (Ident[P] = '_')) then begin
         If Not (Ident[P] in ['0'..'9']) then Exit(False);
         If(P = 1) then Exit(False)
      end
   end;
   
   Exit(True)
end;


Function ParseSection(Sect:AnsiString;Out Package_, Unit_:AnsiString):Boolean;
Var
   P: sInt;
   Fragment: AnsiString;
begin
   Sect := LowerCase(Trim(Sect));
   If Not (DeleteUntil(Sect, ':', @Fragment)) then begin
      Writeln(stderr, 'fpman: section must be either "package:" or "unit:"');
      Exit(False)
   end;
   
   If(Fragment = 'package') then begin
      If Not (IdentifierIsValid(Sect)) then begin
         Writeln(stderr, 'fpman: "'+Sect+'" is not a valid package name');
         Exit(False)
      end;
      
      Package_ := Sect;
      Unit_ := ''
   end else
   If(Fragment = 'unit') then begin
      P := Pos('.', Sect);
      If(P > 0) then begin
         Package_ := Copy(Sect, 1, P-1);
         If Not (IdentifierIsValid(Package_)) then begin
            Writeln(stderr, 'fpman: "'+Package_+'" is not a valid package name');
            Exit(False)
         end
      end else
         Package_ := '';
      
      Unit_ := Copy(Sect, P+1, Length(Sect));
      If Not (IdentifierIsValid(Unit_)) then begin
         Writeln('fpman: "'+Unit_+'" is not a valid unit name');
         Exit(False)
      end
   end else begin
      Writeln(stderr, 'fpman: section must be either "package:" or "unit:"');
      Exit(False)
   end;
   
   Exit(True)
end;


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

end.
