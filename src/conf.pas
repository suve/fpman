unit conf;

{$INCLUDE defines.inc}


interface

Const
   VERSION_MAJOR = '1';
   VERSION_MINOR = '2';
   VERSION_BUGFX = '0';
   
   VERSION_STRING = VERSION_MAJOR + '.' + VERSION_MINOR + '.' + VERSION_BUGFX;

Function GetConfPath():AnsiString;

Function BuildNum():ShortString;


implementation
   uses SysUtils;

Const
   HomeVar = 'HOME';
   ConfDir = '/.suve/fpman/';

Var
   ConfPath: AnsiString = '';

Function GetConfPath():AnsiString;
begin
   If(ConfPath = '') then ConfPath := GetEnvironmentVariable(HomeVar) + ConfDir;
   Result := ConfPath
end;

Function BuildNum():ShortString;
Var
   D,T:ShortString;
begin
   // Include compile date and time
   D:={$I %DATE%}; T:={$I %TIME%};
   //        Y    Y    Y    Y     -  M    M     -  D    D      ,   H    H     :  M    M   
   Result := D[1]+D[2]+D[3]+D[4]+'-'+D[6]+D[7]+'-'+D[9]+D[10]+', '+T[1]+T[2]+':'+T[4]+T[5]
end;

end.
