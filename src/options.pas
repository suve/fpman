unit options;

{$INCLUDE defines.inc}

interface

Type
   TProgramMode = (
      MODE_PAGE,
      MODE_LIST,
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
      'Usage: fpman OPTION | PAGE '                                                   + #10 +
      ' PAGE'                                                                         + #10 +
      '        When no option is specified, fpman requires a PAGE argument. It will'  + #10 +
      '        then search its sqlite database for a matching entry. For routines and'+ #10 +
      '        properties which are part of object / class / interface definition,'   + #10 +
      '        PAGE must be in TYPE.MEMBER format. To avoid ambiguity, PAGE can be'   + #10 +
      '        prefixed with unit name, and even package name, if required - as in'   + #10 +
      '        package.unit.page. The wildcards ? * can be used in PAGE. If the page' + #10 +
      '        is found, fpman will execute man to display it. If multiple matching'  + #10 +
      '        pages are found, fpman will print a list of matching pages and ask'    + #10 +
      '        which page to display.'                                                + #10 +
      ' --list PAGE'                                                                  + #10 +
      '        Like the default mode of operation, except that instead of firing man,'+ #10 +
      '        prints a summary of each matching page.'                               + #10 +
      ' --import PATH'                                                                + #10 +
      '        Imports .html or .man documentation files from PATH to fpman library.' + #10 +
      '        PATH can specify either a single file to import, or a directory to'    + #10 +
      '        scan for .html/.man files. Subdirectories will be scanned recursively.'+ #10 +
      ' --purge[=SECTION]'                                                            + #10 +
      '        Cleans fpman library directory and sqlite database. If SECTION is'     + #10 +
      '        specified, instead of the whole library, only the selected part will'  + #10 +
      '        be purged. SECTION must be in "type:name" format, where type must be'  + #10 +
      '        either "package" or "unit". Unit names can be prefixed with the'       + #10 +
      '        package name, followed by a dot, to avoid ambiguity.'                  + #10 +
      ' --rebuild[=SECTION]'                                                          + #10 +
      '        Purges fpman sqlite database, and then rebuilds its contents based on' + #10 +
      '        files found in the library directory. SECTION can be used in the same' + #10 +
      '        manner as in the --purge option.'                                      + #10 +
      ' --revalidate[=SECTION]'                                                       + #10 +
      '        Looks through all the entries present in sqlite database and checks if'+ #10 +
      '        their manpages are still in library. Any dead entries are removed from'+ #10 +
      '        the database. SECTION can be used in the same manner as in --purge or' + #10 +
      '        --rebuild options.'                                                    + #10 +
      ' --help'                                                                       + #10 +
      '        Displays this help list and exits.'                                    + #10 +
      ' --version'                                                                    + #10 +
      '        Displays version information and exits.'                               + #10 +
   ''
end;

Const
   ARG_NON = No_Argument;
   ARG_REQ = Required_Argument;
   ARG_OPT = Optional_Argument;

Procedure ParseArgs();
Const
   OPTION_NUM = 7;
   OPTIONS : Array[0 .. OPTION_NUM - 1] of TOption = (
      (Name:      'help'; Has_Arg: ARG_NON; Flag: NIL; Value: 'h'),
      (Name:      'list'; Has_Arg: ARG_REQ; Flag: NIL; Value: 'l'),
      (Name:    'import'; Has_Arg: ARG_REQ; Flag: NIL; Value: 'i'),
      (Name:     'purge'; Has_Arg: ARG_OPT; Flag: NIL; Value: 'p'),
      (Name:   'rebuild'; Has_Arg: ARG_OPT; Flag: NIL; Value: 'R'),
      (Name:'revalidate'; Has_Arg: ARG_OPT; Flag: NIL; Value: 'r'),
      (Name:   'version'; Has_Arg: ARG_NON; Flag: NIL; Value: 'v')
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
         'p': begin
            Mode := MODE_PURGE;
            ModeArg := OptArg
         end;
         
         'r': begin
            Mode := MODE_REVALIDATE;
            ModeArg := OptArg
         end;
         
         'R': begin
            Mode := MODE_REBUILD;
            ModeArg := OptArg
         end;
         
         'i': begin
            Mode := MODE_IMPORT;
            ModeArg := OptArg
         end;
         
         'l': begin
            Mode := MODE_LIST;
            ModeArg := OptArg
         end;
         
         '?': begin
            Writeln(stderr, 'fpman: error while parsing options');
            Halt(1)
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
