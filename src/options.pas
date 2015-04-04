unit options;

{$INCLUDE defines.inc}

interface

Type
   TProgramMode = (
      MODE_PAGE,
      MODE_IMPORT,
      MODE_PURGE,
      MODE_REBUILD,
      MODE_REVALIDATE
   );

Var
   Mode : TProgramMode;
   ModeArg : AnsiString;

Function Usage():AnsiString;

Procedure ParseArgs();


implementation
   uses getopts, Conf;

Function Usage():AnsiString;
begin
   Result :=
      'Usage: fpman [OPTION...] [page]'                                                 + #13#10 +
      ' --help               Display this help list.'                                   + #13#10 +
      ' --import PATH        Imports .html documentation files from PATH to fpman'      + #13#10 +
      '                      library. PATH can specify either a single file to import,' + #13#10 + 
      '                      or a directory to scan for .html files. Subdirectories'    + #13#10 +
      '                      will be scanned recursively.'                              + #13#10 +
      ' --purge              Cleans fpman cache directory and sqlite database.'         + #13#10 +
      ' --rebuild            Rebuilds fpman sqlite database based on files found   '    + #13#10 +
      '                      in the cache directory.'                                   + #13#10 +
      ' --revalidate         Like --rebuild, but instead of recreating the database'    + #13#10 +
      '                      from scratch, takes all entries and checks if their'       + #13#10 +
      '                      manpages are still in cache, removing dead entries.'       + #13#10 +
      ' --version            Displays version information and exists.'                  + #13#10 +
   ''
end;

Procedure ParseArgs();
Const
   OPTION_NUM = 6;
   OPTIONS : Array[0 .. OPTION_NUM - 1] of TOption = (
      (Name:      'help'; Has_Arg:       No_Argument; Flag: NIL; Value: 'h'),
      (Name:    'import'; Has_Arg: Required_Argument; Flag: NIL; Value: 'i'),
      (Name:     'purge'; Has_Arg:       No_Argument; Flag: NIL; Value: 'p'),
      (Name:   'rebuild'; Has_Arg:       No_Argument; Flag: NIL; Value: 'R'),
      (Name:'revalidate'; Has_Arg:       No_Argument; Flag: NIL; Value: 'r'),
      (Name:   'version'; Has_Arg:       No_Argument; Flag: NIL; Value: 'v')
   );
Var
   OptionIndex : LongInt;
   opt : Char;
begin
   Mode := MODE_PAGE;
   ModeArg := ParamStr(1);
   OptionIndex := 0;
   
   While(True) do begin
      opt := GetLongOpts('', @OPTIONS[0], OptionIndex);
      If(opt = EndOfOptions) then Exit();
      
      Case(opt) of
         'p': Mode := MODE_PURGE;
         'r': Mode := MODE_REVALIDATE;
         'R': Mode := MODE_REBUILD;
         
         'i': begin
            Mode := MODE_IMPORT;
            ModeArg := OptArg
         end;
         
         'h': begin
            Write(Usage());
            Halt()
         end;
         
         'v': begin
            Writeln('fpman v.', VERSION_STRING,' by suve');
            Writeln(
               'built by ', {$I %USER%},
               ' at ',  {$I %HOSTNAME%},
               ' on ',BuildNum()
               {$IFDEF FPC},' using FPC ',{$I %FPCVERSION%}{$ENDIF}
            );
            Halt()
         end;
      end
   end;
end;


end.
