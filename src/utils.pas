unit utils;

{$INCLUDE defines.inc}


interface

Function DeleteUntil(Var Target:AnsiString; Const Limiter:AnsiString; Const StoreInto:PAnsiString = NIL):Boolean;
Function TimeDiff(Const StartTime, EndTime:Comp):AnsiString;


implementation


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

end.
