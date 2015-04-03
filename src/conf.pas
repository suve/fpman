unit conf;

{$INCLUDE defines.inc}


interface

Const
   VERSION_MAJOR = '0';
   VERSION_MINOR = '3';
   VERSION_BUGFX = '0';
   
   VERSION_STRING = VERSION_MAJOR + '.' + VERSION_MINOR + '.' + VERSION_BUGFX;

Function GetConfPath():AnsiString;

Function BuildNum():ShortString;


implementation
   uses SysUtils;

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

Function BuildNum():ShortString;
Var
   D,T:ShortString;
begin
   // Include compile date and time
   D:={$I %DATE%}; T:={$I %TIME%};
   //        Y    Y    Y    Y     /  M    M    D    D      /  H    H    M    M   
   Result := D[1]+D[2]+D[3]+D[4]+'/'+D[6]+D[7]+D[9]+D[10]+'/'+T[1]+T[2]+T[4]+T[5]
end;

end.
