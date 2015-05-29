unit db;

{$INCLUDE defines.inc}

{*
 * DELETE FROM `pages` WHERE `page_Id` IN (
 *   SELECT `page_Id` FROM `view_pages` WHERE `unit_Name` = 'dos'
 * );
 *}

interface
   uses sqlite3, descriptions, dynarray;

Type
   TResultRow = record
      ID : sInt;
      Package_, Unit_, Page : AnsiString;
   end;
   
   TResultSet = specialize GenericDynArray<TResultRow>;

Function Init(Const WasCreated:PBoolean = NIL):Boolean;
Function Quit():Boolean;

Function CreateTables():Boolean;
Function AddPage(Const Desc:TFunctionDesc):Boolean;

Function FindPage(PageName:AnsiString; Var rset:TResultSet):Boolean;
Function FindSimilarPages(PageName:AnsiString; Var rset:TResultSet):Boolean;
Function NumberOfPages(Out Number:sInt):Boolean;

Function ListPages(PackName, UnitName:AnsiString; Var rset:TResultSet):Boolean;
Function DeletePages(PackName, UnitName:AnsiString):Boolean;

Function FindUnit(Const PackId:sInt; UnitName:AnsiString; Var rset:TResultSet):Boolean;
Function FindPackage(PackName:AnsiString; Var rset:TResultSet):Boolean;

Function PurgeTables():Boolean;
Function DeletePages(Const ID : Array of sInt):Boolean;


implementation
   uses SysUtils, Conf, dictionary;

Type
   TIDDict = specialize GenericDictionary<sInt>;

Var
   Datab : Psqlite3;
   PkgDict, UnitDict: TIDDict;

Function Init(Const WasCreated:PBoolean):Boolean;
Var
   DBpath: AnsiString;
   FiEx: Boolean;
begin
   DBpath := GetConfPath() + 'fpman.sqlite';
   FiEx := Not FileExists(DBpath);
   
   If(FiEx) then 
      If(Not ForceDirectories(GetConfPath())) then begin
         Writeln(stderr, 'fpman: failed to create config directory');
         Exit(False)
      end;
   
   If(sqlite3_open(PChar(GetConfPath() + 'fpman.sqlite'), @Datab) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to open fpman.sqlite: ',sqlite3_errmsg(Datab));
      Exit(False);
   end;
   
   PkgDict.Create(-1, 4);
   UnitDict.Create(-1, 16);
   
   If(WasCreated <> NIL) then WasCreated^ := FiEx;
   Exit(True)
end;

Function Quit():Boolean;
begin
   PkgDict.Purge();
   UnitDict.Purge();
   
   If(sqlite3_close(Datab) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to close fpman.sqlite: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;

Function CreateTables():Boolean;
Const
   STATEMENT_NUM = 6;
   
   StmtName : Array[1 .. STATEMENT_NUM] of AnsiString = (
      'PRAGMA',
      'CREATE TABLE `packages`',  'CREATE TABLE `units`', 'CREATE TABLE `pages`',
      'CREATE VIEW `view_units`', 'CREATE VIEW `view_pages`'
   );
   
   
   SQL : Array[1 .. STATEMENT_NUM] of AnsiString = (
      'PRAGMA page_size = 4096',
      
      'CREATE TABLE IF NOT EXISTS `packages` ('+
         '`pkg_Id` INTEGER PRIMARY KEY ASC ON CONFLICT FAIL AUTOINCREMENT,'+
         '`pkg_Name` TEXT'+
       ')',
   
      'CREATE TABLE IF NOT EXISTS `units` ('+
         '`unit_Id` INTEGER PRIMARY KEY ASC ON CONFLICT FAIL AUTOINCREMENT,'+
         '`unit_pkgId` INTEGER REFERENCES `packages` (`pkg_Id`),'+
         '`unit_Name` TEXT'+
      ')',
   
      'CREATE TABLE IF NOT EXISTS `pages` ('+
         '`page_Id` INTEGER PRIMARY KEY ASC ON CONFLICT FAIL,'+
         '`page_unitId` INTEGER REFERENCES `units` (`unit_Id`),'+
         '`page_Name` TEXT'+
      ')',
      
      'CREATE VIEW IF NOT EXISTS `view_units` AS SELECT '+
         '`p`.`pkg_Id` AS `pkg_Id`, '+
         '`p`.`pkg_Name` AS `pkg_Name`, '+
         '`u`.`unit_Id` AS `unit_Id`, '+
         '`u`.`unit_Name` AS `unit_Name` '+
         'FROM `units` `u` '+
         'LEFT JOIN `packages` `p` '+
         'ON `u`.`unit_pkgId` = `p`.`pkg_Id`'+
      '',
      
      'CREATE VIEW IF NOT EXISTS `view_pages` AS SELECT '+
         '`u`.`pkg_Id` AS `pkg_Id`, '+
         '`u`.`pkg_Name` AS `pkg_Name`, '+
         '`u`.`unit_Id` AS `unit_Id`, '+
         '`u`.`unit_Name` AS `unit_Name`, '+
         '`p`.`page_Id` AS `page_Id`, '+
         '`p`.`page_Name` AS `page_Name`, '+
         '(IFNULL(`u`.`pkg_Name`,''unknown'') || ''.'' || IFNULL(`u`.`unit_Name`,''unknown'') || ''.'' || `p`.`page_Name`) AS `fullName`'+
         'FROM `pages` `p` '+
         'LEFT JOIN `view_units` `u` '+
         'ON `p`.`page_unitId` = `u`.`unit_Id`'+
      ''
   );
   
Var
   Idx : sInt;
   Stat : Psqlite3_stmt;
begin
   For Idx := 1 to STATEMENT_NUM do begin
      If(sqlite3_prepare(Datab, PChar(SQL[Idx]), -1, @Stat, NIL) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to prepare ',StmtName[Idx],' statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(sqlite3_step(Stat) <> SQLITE_DONE) then begin
         Writeln(stderr, 'fpman: failed to execute ',StmtName[Idx],' statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to finalize ',StmtName[Idx],' statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
   end;
   
   Exit(True)
end;

Function InsertID(Const TableName, NameCol, InsertValue:AnsiString; Const fkID:sInt; Const fkCol:AnsiString):Boolean;
Var
   NameIdx : sInt;
   Stat : Psqlite3_stmt;
   SQL : AnsiString;
begin
   If(fkId > -1) then NameIdx := 2 else NameIdx := 1;

   SQL := 'INSERT INTO `' + TableName + '` (';
   If(fkID > -1) then SQL += '`' + fkCol + '`, ';
   SQL += '`' + NameCol + '`) VALUES (';
   If(fkID > -1) then SQL += '?, ';
   SQL += '?)';
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare INSERT INTO `',TableName,'` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(fkID > -1) then begin
      If(sqlite3_bind_int(Stat, 1, fkId) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to bind argument for INSERT INTO `',TableName,'` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
   end;
   
   If(sqlite3_bind_text(Stat, NameIdx, PChar(InsertValue), -1, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to bind argument for INSERT INTO `',TableName,'` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(sqlite3_step(Stat) <> SQLITE_DONE) then begin
      Writeln(stderr, 'fpman: failed to execute INSERT INTO `',TableName,'` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize INSERT INTO `',TableName,'` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;

Function SelectID(Out ID:sInt; Const TableName, NameCol, SearchFor:AnsiString; Const fkID:sInt; Const fkCol:AnsiString):Boolean;
Var
   Code : sInt;
   Stat : Psqlite3_stmt;
   SQL : AnsiString;
begin
   ID := -1;
   SQL := 'SELECT * FROM `' + TableName + '` WHERE (`' + NameCol + '` = ?)';
   If(fkCol <> '') then SQL += ' AND (`' + fkCol + '` = ?)';
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare SELECT FROM `',TableName,'` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(sqlite3_bind_text(Stat, 1, PChar(SearchFor), -1, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `',TableName,'` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(fkCol <> '') then begin
      If(sqlite3_bind_int(Stat, 2, fkId) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `',TableName,'` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end
   end;
   
   Code := sqlite3_step(Stat);
   If(Not (Code in [SQLITE_DONE, SQLITE_ROW])) then begin
      Writeln(stderr, 'fpman: failed to execute SELECT FROM `',TableName,'` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(Code = SQLITE_ROW) then begin
      If(sqlite3_column_type(Stat, 0) <> SQLITE_INTEGER) then begin
         Writeln(stderr, 'fpman: first column in `',TableName,'` is not of type INTEGER');
         Exit(False)
      end;
      
      ID := sqlite3_column_int(Stat, 0)
   end;
   
   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize SELECT FROM `',TableName,'` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;

Function GetID(Out ID:sInt; Const TableName, NameCol, SearchFor:AnsiString; Const fkID:sInt = -1; Const fkCol:AnsiString = ''):Boolean;
begin
   If(Not (SelectID(ID, TableName, NameCol, SearchFor, fkId, fkCol))) then Exit(False);
   If(ID <> -1) then Exit(True);
   
   If(Not (InsertID(TableName, NameCol, SearchFor, fkID, fkCol))) then Exit(False);
   
   If(Not (SelectID(ID, TableName, NameCol, SearchFor, fkId, fkCol))) then Exit(False);
   Exit(ID <> -1)
end;

Function AddPage(Const Desc:TFunctionDesc):Boolean;
Var
   PackageId, UnitId, PageId : sInt;
begin
   UnitId := UnitDict[Desc.Package_ + '.' + Desc.Unit_];
   If(UnitId < 0) then begin
      
      PackageId := PkgDict[Desc.Package_];
      If(PackageId < 0) then begin
         If(Not GetID(PackageId, 'packages', 'pkg_Name', Desc.Package_)) then begin
            Writeln(stderr, 'fpman: failed to SELECT / INSERT package from database');
            Exit(False)
         end;
         
         PkgDict[Desc.Package_] := PackageId
      end;
      
      If(Not GetID(UnitId, 'units', 'unit_Name', Desc.Unit_, PackageId, 'unit_pkgId')) then begin
         Writeln(stderr, 'fpman: failed to SELECT / INSERT unit from database');
         Exit(False)
      end;
      
      UnitDict[Desc.Package_ + '.' + Desc.Unit_] := UnitId
   end;
   
   If(Not GetID(PageId, 'pages', 'page_Name', Desc.Name, UnitId, 'page_unitId')) then begin
      Writeln(stderr, 'fpman: failed to SELECT / INSERT page from database');
      Exit(False)
   end;
   
   Exit(True)
end;


Function SearchForPage(Const Package_, Unit_, Page : AnsiString; Var rset:TResultSet):Boolean;
Var
   ArgIdx, Code : sInt;
   Stat : Psqlite3_stmt;
   SQL : AnsiString;
   Row : TResultRow;
begin
   SQL := 'SELECT `page_Id`, `pkg_Name`, `unit_Name`, `page_Name` FROM `view_pages` WHERE (';
      If(Package_ <> '') then SQL += '`pkg_Name` LIKE ? ESCAPE ''\'') AND (';
      If(Unit_ <> '') then SQL += '`unit_Name` LIKE ? ESCAPE ''\'') AND (';
   SQL += '`page_Name` LIKE ? ESCAPE ''\'')';
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   ArgIdx := 0;
   
   If(Package_ <> '') then begin
      ArgIdx += 1;
      If(sqlite3_bind_text(Stat, ArgIdx, PChar(Package_), -1, NIL) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
   end end;
   
   If(Unit_ <> '') then begin
      ArgIdx += 1;
      If(sqlite3_bind_text(Stat, ArgIdx, PChar(Unit_), -1, NIL) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
   end end;
   
   ArgIdx += 1;
   If(sqlite3_bind_text(Stat, ArgIdx, PChar(Page), -1, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   While(True) do begin
      Code := sqlite3_step(Stat);
      If(Not (Code in [SQLITE_DONE, SQLITE_ROW])) then begin
         Writeln(stderr, 'fpman: failed to execute SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(Code = SQLITE_DONE) then Break;
   
      Row.ID := sqlite3_column_int(Stat, 0);
      
      Row.Package_ := sqlite3_column_text(Stat, 1);
      Row.Unit_ := sqlite3_column_text(Stat, 2);
      Row.Page := sqlite3_column_text(Stat, 3);
      
      rset.Push(Row)
   end;
   
   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;


Function FindPage(PageName:AnsiString; Var rset:TResultSet):Boolean;
Var
   Package_, Unit_ : AnsiString;
   P : sInt;
begin
   rset.Purge();
   
   // Escape SQL wildcards
   PageName := StringReplace(PageName, '\', '\\', [rfReplaceAll]);
   PageName := StringReplace(PageName, '_', '\_', [rfReplaceAll]);
   PageName := StringReplace(PageName, '%', '\%', [rfReplaceAll]);
   // Replace standard wildcards with SQL ones
   PageName := StringReplace(PageName, '?', '_', [rfReplaceAll]);
   PageName := StringReplace(PageName, '*', '%', [rfReplaceAll]);
   
   // Search for page using identifier
   If(Not SearchForPage('', '', PageName, rset)) then Exit(False);
   If(rset.Count > 0) then Exit(True);
   
   // Look for dot. If not found (or first char), return
   P := Pos('.', PageName);
   If(P <= 1) then Exit(True);
   
   // Extract unit from pagename
   Unit_ := LeftStr(PageName, P - 1);
   Delete(PageName, 1, P);
   
   // Try again with unit + identifier
   If(Not SearchForPage('', Unit_, PageName, rset)) then Exit(False);
   If(rset.Count > 0) then Exit(True);
   
   // Look for dot again, return if not found or first char
   P := Pos('.', PageName);
   If(P < 1) then Exit(True);
   
   // Extract parts again
   Package_ := Unit_;
   Unit_ := LeftStr(PageName, P - 1);
   Delete(PageName, 1, P);
   
   // Search one last time
   If(Not SearchForPage(Package_, Unit_, PageName, rset)) then Exit(False);
   Exit(True);
end;


Function FindSimilarPages(PageName:AnsiString; Var rset:TResultSet):Boolean;
Var
   Code : sInt;
   Stat : Psqlite3_stmt;
   SQL : AnsiString;
   Row : TResultRow;
begin
   rset.Purge();
   
   // Escape SQL wildcards
   PageName := StringReplace(PageName, '\', '\\', [rfReplaceAll]);
   PageName := StringReplace(PageName, '_', '\_', [rfReplaceAll]);
   PageName := StringReplace(PageName, '%', '\%', [rfReplaceAll]);
   // Replace standard wildcards with SQL ones
   PageName := StringReplace(PageName, '?', '_', [rfReplaceAll]);
   PageName := StringReplace(PageName, '*', '%', [rfReplaceAll]);
   // We're looking for similar pages, so anything containing the name counts, too
   PageName := '%' + PageName + '%';
   
   SQL := 'SELECT `page_Id`, `pkg_Name`, `unit_Name`, `page_Name` FROM `view_pages` WHERE (`fullName` LIKE ? ESCAPE ''\'')';
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(sqlite3_bind_text(Stat, 1, PChar(PageName), -1, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   While(True) do begin
      Code := sqlite3_step(Stat);
      If(Not (Code in [SQLITE_DONE, SQLITE_ROW])) then begin
         Writeln(stderr, 'fpman: failed to execute SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(Code = SQLITE_DONE) then Break;
   
      Row.ID := sqlite3_column_int(Stat, 0);
      
      Row.Package_ := sqlite3_column_text(Stat, 1);
      Row.Unit_ := sqlite3_column_text(Stat, 2);
      Row.Page := sqlite3_column_text(Stat, 3);
      
      rset.Push(Row)
   end;
   
   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;


Function ListPages(PackName, UnitName:AnsiString; Var rset:TResultSet):Boolean;
Var
   Code, ArgIdx: sInt;
   Stat: Psqlite3_stmt;
   SQL: AnsiString;
   Row: TResultRow;
begin
   rset.Purge();
   SQL := 'SELECT `page_Id`, `pkg_Name`, `unit_Name`, `page_Name` FROM `view_pages`';
   
   If((PackName <> '') or (UnitName <> '')) then begin
      SQL += ' WHERE ';
      
      If(PackName <> '') then begin
         PackName := StringReplace(PackName, '\', '\\', [rfReplaceAll]);
         PackName := StringReplace(PackName, '_', '\_', [rfReplaceAll]);
         PackName := StringReplace(PackName, '%', '\%', [rfReplaceAll]);
         
         SQL += '(`pkg_Name` LIKE ? ESCAPE ''\'')';
         If(UnitName <> '') then SQL += ' AND '
      end;
      
      If(UnitName <> '') then begin
         UnitName := StringReplace(UnitName, '\', '\\', [rfReplaceAll]);
         UnitName := StringReplace(UnitName, '_', '\_', [rfReplaceAll]);
         UnitName := StringReplace(UnitName, '%', '\%', [rfReplaceAll]);
         
         SQL += '(`unit_Name` LIKE ? ESCAPE ''\'')'
      end;
   end;
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If((PackName <> '') or (UnitName <> '')) then begin
      ArgIdx := 0;
      
      If(PackName <> '') then begin
         ArgIdx += 1;
         If(sqlite3_bind_text(Stat, ArgIdx, PChar(PackName), -1, NIL) <> SQLITE_OK) then begin
            Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
            Exit(False)
         end
      end;
      
      If(UnitName <> '') then begin
         ArgIdx += 1;
         If(sqlite3_bind_text(Stat, ArgIdx, PChar(UnitName), -1, NIL) <> SQLITE_OK) then begin
            Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
            Exit(False)
         end
      end
   end;
   
   While(True) do begin
      Code := sqlite3_step(Stat);
      If(Not (Code in [SQLITE_DONE, SQLITE_ROW])) then begin
         Writeln(stderr, 'fpman: failed to execute SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(Code = SQLITE_DONE) then Break;
   
      Row.ID := sqlite3_column_int(Stat, 0);
      Row.Package_ := sqlite3_column_text(Stat, 1);
      Row.Unit_ := sqlite3_column_text(Stat, 2);
      Row.Page := sqlite3_column_text(Stat, 3);
      
      rset.Push(Row)
   end;
   
   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize SELECT FROM `view_pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;

Function DeletePages(PackName, UnitName:AnsiString):Boolean;
Var
   ArgIdx: sInt;
   Stat: Psqlite3_stmt;
   SQL: AnsiString;
begin
   SQL := 'DELETE FROM `pages` WHERE `page_Id` IN (';
   SQL += 'SELECT `page_Id` FROM `view_pages`';
   
   If((PackName <> '') or (UnitName <> '')) then begin
      SQL += ' WHERE ';
      
      If(PackName <> '') then begin
         PackName := StringReplace(PackName, '\', '\\', [rfReplaceAll]);
         PackName := StringReplace(PackName, '_', '\_', [rfReplaceAll]);
         PackName := StringReplace(PackName, '%', '\%', [rfReplaceAll]);
         
         SQL += '(`pkg_Name` LIKE ? ESCAPE ''\'')';
         If(UnitName <> '') then SQL += ' AND '
      end;
      
      If(UnitName <> '') then begin
         UnitName := StringReplace(UnitName, '\', '\\', [rfReplaceAll]);
         UnitName := StringReplace(UnitName, '_', '\_', [rfReplaceAll]);
         UnitName := StringReplace(UnitName, '%', '\%', [rfReplaceAll]);
         
         SQL += '(`unit_Name` LIKE ? ESCAPE ''\'')'
      end;
   end;
   SQL += ');';
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare DELETE FROM `pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If((PackName <> '') or (UnitName <> '')) then begin
      ArgIdx := 0;
      
      If(PackName <> '') then begin
         ArgIdx += 1;
         If(sqlite3_bind_text(Stat, ArgIdx, PChar(PackName), -1, NIL) <> SQLITE_OK) then begin
            Writeln(stderr, 'fpman: failed to bind argument for DELETE FROM `pages` statement: ',sqlite3_errmsg(Datab));
            Exit(False)
         end
      end;
      
      If(UnitName <> '') then begin
         ArgIdx += 1;
         If(sqlite3_bind_text(Stat, ArgIdx, PChar(UnitName), -1, NIL) <> SQLITE_OK) then begin
            Writeln(stderr, 'fpman: failed to bind argument for DELETE FROM `pages` statement: ',sqlite3_errmsg(Datab));
            Exit(False)
         end
      end
   end;
   
   If(sqlite3_step(Stat) <> SQLITE_DONE) then begin
      Writeln(stderr, 'fpman: failed to execute ',SQL,' statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;

   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize ',SQL,' statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;



Function FindPackage(PackName: AnsiString; Var rset:TResultSet):Boolean;
Var
   Code: sInt;
   Stat: Psqlite3_stmt;
   SQL: AnsiString;
   Row: TResultRow;
begin
   rset.Purge();
   
   // Escape SQL wildcards
   PackName := StringReplace(PackName, '\', '\\', [rfReplaceAll]);
   PackName := StringReplace(PackName, '_', '\_', [rfReplaceAll]);
   PackName := StringReplace(PackName, '%', '\%', [rfReplaceAll]);
   
   SQL := 'SELECT `pkg_Id`, `pkg_Name` FROM `packages` WHERE (`pkg_Name` LIKE ? ESCAPE ''\'')';
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare SELECT FROM `packages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(sqlite3_bind_text(Stat, 0, PChar(PackName), -1, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `packages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   While(True) do begin
      Code := sqlite3_step(Stat);
      If(Not (Code in [SQLITE_DONE, SQLITE_ROW])) then begin
         Writeln(stderr, 'fpman: failed to execute SELECT FROM `packages` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(Code = SQLITE_DONE) then Break;
   
      Row.ID := sqlite3_column_int(Stat, 0);
      Row.Package_ := sqlite3_column_text(Stat, 1);
      
      rset.Push(Row)
   end;
   
   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize SELECT FROM `packages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;


Function FindUnit(Const PackId:sInt; UnitName: AnsiString; Var rset:TResultSet):Boolean;
Var
   Code: sInt;
   Stat: Psqlite3_stmt;
   SQL: AnsiString;
   Row: TResultRow;
begin
   rset.Purge();
   
   // Escape SQL wildcards
   UnitName := StringReplace(UnitName, '\', '\\', [rfReplaceAll]);
   UnitName := StringReplace(UnitName, '_', '\_', [rfReplaceAll]);
   UnitName := StringReplace(UnitName, '%', '\%', [rfReplaceAll]);
   
   SQL := 'SELECT `unit_Id`, `unit_Name` FROM `units` WHERE ';
   If(PackId >= 0) then SQL += '(`unit_pkgId` = '+IntToStr(PackId)+') AND ';
   SQL += '(`unit_Name` LIKE ? ESCAPE ''\'')';
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare SELECT FROM `units` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(sqlite3_bind_text(Stat, 0, PChar(UnitName), -1, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to bind argument for SELECT FROM `units` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   While(True) do begin
      Code := sqlite3_step(Stat);
      If(Not (Code in [SQLITE_DONE, SQLITE_ROW])) then begin
         Writeln(stderr, 'fpman: failed to execute SELECT FROM `units` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(Code = SQLITE_DONE) then Break;
   
      Row.ID := sqlite3_column_int(Stat, 0);
      Row.Unit_ := sqlite3_column_text(Stat, 1);
      
      rset.Push(Row)
   end;
   
   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize SELECT FROM `units` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;


Function NumberOfPages(Out Number:sInt):Boolean;
Const
   SQL = 'SELECT COUNT(*) AS `number` FROM `pages`';
Var
   Code : sInt;
   Stat : Psqlite3_stmt;
begin
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare SELECT COUNT(*) statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Code := sqlite3_step(Stat);
   If(Not (Code in [SQLITE_DONE, SQLITE_ROW])) then begin
      Writeln(stderr, 'fpman: failed to execute SELECT COUNT(*) statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(Code = SQLITE_ROW)
      then Number := sqlite3_column_int(Stat, 0)
      else Number := 0;
   
   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize SELECT COUNT(*) statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;


Function PurgeTables():Boolean;
Const
   TABLE_NUM = 3;
   TABLES : Array[1 .. TABLE_NUM] of String = (
      'pages', 'units', 'packages'
   );
Var 
   Idx : sInt;
   Stat : Psqlite3_stmt;
   SQL : AnsiString;
begin
   For Idx := 1 to TABLE_NUM do begin
      SQL := 'DELETE FROM `' + TABLES[Idx] + '`';
      
      If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to prepare ',SQL,' statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(sqlite3_step(Stat) <> SQLITE_DONE) then begin
         Writeln(stderr, 'fpman: failed to execute ',SQL,' statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;

      If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to finalize ',SQL,' statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      SQL := 'UPDATE `sqlite_sequence` SET `seq` = 0 WHERE `name` = '''+TABLES[Idx]+'''';
      
      If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to prepare UPDATE `sqlite_sequence` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
      
      If(sqlite3_step(Stat) <> SQLITE_DONE) then begin
         Writeln(stderr, 'fpman: failed to execute UPDATE `sqlite_sequence` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;

      If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
         Writeln(stderr, 'fpman: failed to finalize UPDATE `sqlite_sequence` statement: ',sqlite3_errmsg(Datab));
         Exit(False)
      end;
   end;
   
   PkgDict.Purge();
   UnitDict.Purge();
   
   Exit(True)
end;


Function DeletePages(Const ID : Array of sInt):Boolean;
Var 
   Stat : Psqlite3_stmt;
   SQL : AnsiString;
   Idx : sInt;
begin
   SQL := 'DELETE FROM `pages` WHERE `page_Id` IN (';
   For Idx := Low(ID) to High(ID) do SQL += IntToStr(ID[Idx]) + ',';
   SQL[Length(SQL)] := ')';
   
   If(sqlite3_prepare(Datab, PChar(SQL), -1, @Stat, NIL) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to prepare DELETE FROM `pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   If(sqlite3_step(Stat) <> SQLITE_DONE) then begin
      Writeln(stderr, 'fpman: failed to execute DELETE FROM `pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;

   If(sqlite3_finalize(Stat) <> SQLITE_OK) then begin
      Writeln(stderr, 'fpman: failed to finalize DELETE FROM `pages` statement: ',sqlite3_errmsg(Datab));
      Exit(False)
   end;
   
   Exit(True)
end;

end.
