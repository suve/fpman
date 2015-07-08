unit op_rebuild;

{$INCLUDE defines.inc}

interface

Procedure Operation_Rebuild();


implementation

uses
   SysUtils, Unix,
   dynarray,
   conf, options, descriptions, db, troff, utils;

Type
   TDescArray = specialize GenericDynArray<TFunctionDesc>;

Var
   Desc: TFunctionDesc;
   DescList: TDescArray;
   
   SuccPages, halfPages, SkipPages, FailPages: sInt;

Const
   REBUILD_STEP = 100;

Function ImportMan(Const FilePath:AnsiString):sInt;
Var
   InputStr, InputLine: AnsiString;
   InputFile: System.Text;
   ParseResult: sInt;
begin
   InputStr := '';
   Assign(InputFile, FilePath);
   
   {$I-} Reset(InputFile); {$I+}
   If(IOResult() <> 0) then begin
      Writeln(stderr,'fpman: unable to read ',FilePath);
      Exit(-1)
   end;
   
   While(Not Eof(InputFile)) do begin
      Readln(InputFile, InputLine);
      InputStr += InputLine + #10
   end;
   Close(InputFile);
   
   ParseResult := ParseTroff(InputStr, Desc);
   
   If(ParseResult = -1) then begin
      Writeln(stderr, 'fpman: failed to parse ',FilePath);
      Exit(-1)
   end else
   If(ParseResult = 0) then begin
      Writeln(stderr, 'fpman: ',FilePath,' does not seem to be an fpman manpage');
      Exit(0)
   end;
   
   If(Desc.Package_ <> '')
      then Desc.Package_ := LowerCase(Desc.Package_)
      else Desc.Package_ := 'unknown';
      
   If(Desc.Unit_ <> '')
      then Desc.Unit_ := LowerCase(Desc.Unit_)
      else Desc.Unit_ := 'unknown';
   
   Exit(+1)
end;

Procedure ImportDirectory(Const Directory:AnsiString; Var SuccPages, SkipPages, FailPages : sInt);
Var
   Search: TSearchRec;
   Ext, PathOnly: AnsiString;
begin
   PathOnly := ExtractFilePath(Directory);
   If(RightStr(PathOnly, 1) <> '/') then PathOnly += '/';
   
   If(FindFirst(Directory, faDirectory, Search) = 0) then Repeat
      If((Search.Name = '.') or (Search.Name = '..')) then Continue;
      
      If((Search.Attr and faDirectory) = faDirectory) then begin
         ImportDirectory(PathOnly + Search.Name + '/*', SuccPages, SkipPages, FailPages);
         Continue
      end;
      
      // Ignore non-man files
      Ext := LowerCase(ExtractFileExt(Search.Name));
      If(Ext <> '.man') then Continue;
      
      Case(ImportMan(PathOnly + Search.Name)) of
         +1: begin
            Writeln(stderr, 'fpman: found manpage for ',Desc.Package_,'.',Desc.Unit_,'.',Desc.Name);
            DescList.Push(Desc);
            
            If(DescList.Count >= REBUILD_STEP) then begin
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


Procedure RebuildAll_Purge();
begin
   If(db.PurgeTables()) then begin
      Writeln(stderr, 'fpman: successfully purged sqlite database tables');
      Exit()
   end;
   
   Writeln(stderr, 'fpman: failed to purge sqlite database tables');
   Writeln(stderr, 'fpman: fpman.sqlite will be removed');
   
   db.Quit();
   If(Not DeleteFile(GetConfPath() + 'fpman.sqlite')) then begin
      Writeln(stderr, 'fpman: failed to remove fpman.sqlite');
      Writeln(stderr, 'fpman: aborting rebuild');
      Halt(1)
   end;
   
   If(Not db.Init()) then begin
      Writeln(stderr, 'fpman: failed to create fpman.sqlite, aborting rebuild');
      Halt(1)
   end;
   If(Not db.CreateTables()) then begin
      Writeln(stderr, 'fpman: failed to create tables, aborting rebuild');
      db.Quit();
      Halt(1)
   end
end;

Procedure RebuildAll_Import(Var SuccPages, SkipPages, FailPages: sInt);
begin
   ImportDirectory(GetConfPath() + 'pages/*', SuccPages, SkipPages, FailPages);
end;


Procedure RebuildSection_Purge(Const PackName, UnitName:AnsiString); 
begin
   If(db.DeletePages(PackName, UnitName)) then Exit();

   Writeln(stderr, 'fpman: failed to delete database entries, aborting rebuild');
   db.Quit();
   Halt(1)
end;

Procedure RebuildSection_Import(
   PackName, UnitName:AnsiString;
   Var SuccPages, SkipPages, FailPages: sInt
);
Var
   Idx: sInt;
   PackList: PDirList;
   PossibleDir: AnsiString;
begin
   PackName := LowerCase(PackName);
   UnitName := LowerCase(UnitName);
   
   If(PackName <> '') then begin
      PossibleDir := GetConfPath() + 'pages/' + PackName + '/';
      If(UnitName <> '') then PossibleDir += UnitName + '/';
      
      ImportDirectory(PossibleDir + '*', SuccPages, SkipPages, FailPages)
   end else begin
      PackList := GetDirListing(GetConfPath() + 'pages/', DIRLIST_DIRECTORIES);
      
      For Idx := 0 to (PackList^.Count - 1) do begin
         PossibleDir := GetConfPath() + 'pages/' + PackList^[Idx] + '/' + UnitName;
         If(DirectoryExists(PossibleDir)) then
            ImportDirectory(PossibleDir + '/*', SuccPages, SkipPages, FailPages)
      end;
      
      Dispose(PackList, Destroy())
   end
end;


Procedure Operation_Rebuild();
Var
   StartTime, EndTime: Comp;
   PackName, UnitName: AnsiString;
begin
   StartTime := TimeStampToMSecs(DateTimeToTimeStamp(Now()));
   SuccPages := 0; halfPages := 0; SkipPages := 0; FailPages := 0;
   
   DescList.Create(REBUILD_STEP);
   
   If(ModeArg = '') then
      RebuildAll_Purge()
   else begin
      If(Not ParseSection(ModeArg, PackName, UnitName)) then begin
         db.Quit();
         Halt(1)
      end;
      
      RebuildSection_Purge(PackName, UnitName)
   end;
   
   If(Not EnsureUniquePageIndex()) then begin
      Writeln(stderr, 'fpman: failed to create unique page index');
      Writeln(stderr, 'fpman: aborting rebuild');
      
      db.Quit();
      Halt(1)
   end;
   
   If(ModeArg = '')
      then RebuildAll_Import(SuccPages, SkipPages, FailPages)
      else RebuildSection_Import(PackName, UnitName, SuccPages, SkipPages, FailPages);
   
   If(DescList.Count > 0) then begin
      If(db.AddMultiplePages(DescList.Ptr, DescList.Count)) then begin
         Writeln(stderr, 'fpman: successfully added ',DescList.Count,' pages to database');
         SuccPages += DescList.Count
      end else begin
         Writeln(stderr, 'fpman: failed to add ',DescList.Count,' pages to database');
         HalfPages += DescList.Count
      end
   end;
   DescList.Destroy();
   
   EndTime := TimeStampToMSecs(DateTimeToTimeStamp(Now()));
   
   If(SuccPages > 0) then begin
      Write(stderr, 'fpman: rebuild finished in ',TimeDiff(StartTime,EndTime),', ',SuccPages,' pages rebuilt');
      If(HalfPages > 0) then Write(stderr, ', ',halfPages,' pages outside database');
      If(FailPages > 0) then Write(stderr, ', ',FailPages,' pages failed');
      If(SkipPages > 0) then Write(stderr, ', ',SkipPages,' pages skipped');
      Writeln(stderr);
      
      Halt(0)
   end;
   
   If(FailPages = 0) then begin
      If(SkipPages > 0)
         then Writeln(stderr, 'fpman: rebuild finished in ',TimeDiff(StartTime,EndTime),', ',SkipPages,' pages skipped')
         else Writeln(stderr, 'fpman: rebuild finished in ',TimeDiff(StartTime,EndTime),', no pages found');
      
      Halt(0)
   end;
   
   Write(stderr, 'fpman: rebuild finished in ',TimeDiff(StartTime,EndTime),', failed to rebuild ',FailPages,' pages');
   If(SkipPages > 0) then Write(stderr, ', ', SkipPages,' pages skipped');
   Writeln(stderr);
   
   Writeln(stderr, 'fpman: rebuild failed');
   Halt(1)
end;

end.
