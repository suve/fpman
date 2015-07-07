unit dictionary;

{$INCLUDE defines.inc}

interface

Type
   generic GenericDictionary<Tp> = object
      Protected
         Type
            TDisposeProc = procedure(Item: Tp);
            TDictRecord = record
               Name: AnsiString;
               Value: Tp
            end;
         
         Var
            _Arr : Array of TDictRecord;
            _Len, _Num, _Step : sInt;
            _DefVal: Tp;
         
         Method
            Function  GetItemIndex(Const Name:AnsiString):sInt;
            Procedure AddItem(Const Name:AnsiString; Const Value: Tp);
            
            Function  ReadItem(Const Name: AnsiString):Tp;
            Procedure WriteItem(Const Name: AnsiString; Const Value: Tp);
            
            Procedure SetStep(Const Step:sInt);
            
      Public
         Function Purge():sInt;
         Function Purge(Const FreeItem : TDisposeProc):sInt;
         Function Trim():sInt;
         
         Property Count: sInt read _Num;
         Property Size: sInt read _Len;
         
         Property Step: sInt read _Step write SetStep;
         
         Property Item[Name: AnsiString]: Tp read ReadItem write WriteItem; Default;
         
         {$DEFINE STEP_DEFAULT := 8}
         Constructor Create(Const DefaultVal:Tp; Const StepSize:sInt = STEP_DEFAULT);
         Destructor Destroy();
   end;


implementation
   uses Math, SysUtils;

Function GenericDictionary.GetItemIndex(Const Name:AnsiString):sInt;
Var
   Min, Max, Mid : sInt;
begin
   Min := 0; Max := (_Num - 1);
   While(Min <= Max) do begin
      Mid := (Min + Max) div 2;
      
      Case Sign(CompareStr(Name, _Arr[Mid].Name)) of
         -1: Max := Mid - 1;
          0: Exit(Mid);
         +1: Min := Mid + 1;
      end
   end;
   Exit(-1)
end;

Procedure GenericDictionary.AddItem(Const Name:AnsiString; Const Value: Tp);
Var
   Idx : sInt;
begin
   If(_Num = _Len) then begin
      _Len += _Step;
      SetLength(_Arr, _Len)
   end;
   
   Idx := _Num;
   While((Idx > 0) and (Name < _Arr[Idx - 1].Name)) do begin
      _Arr[Idx] := _Arr[Idx - 1];
      Idx -= 1
   end;
   
   _Arr[Idx].Name := Name;
   _Arr[Idx].Value := Value;
   _Num += 1
end;

Function GenericDictionary.ReadItem(Const Name:AnsiString):Tp;
Var
   Idx : sInt;
begin
   Idx := GetItemIndex(Name);
   
   If(Idx >= 0) then
      Result := _Arr[Idx].Value
   else
      Result := _DefVal
end;

Procedure GenericDictionary.WriteItem(Const Name:AnsiString; Const Value: Tp);
Var
   Idx : sInt;
begin
   Idx := GetItemIndex(Name);
   
   If(Idx >= 0) then
      _Arr[Idx].Value := Value
   else
      AddItem(Name, Value)
end;

Function GenericDictionary.Purge():sInt;
begin
   Result := _Num;
   _Num := 0
end;

Function GenericDictionary.Purge(Const FreeItem : TDisposeProc):sInt;
Var
   Idx : sInt;
begin
   Result := _Num;
   
   For Idx := 0 to (_Num - 1) do FreeItem(_Arr[Idx].Value);
   _Num := 0
end;

Function GenericDictionary.Trim():sInt;
begin
   If(_Len = _Num) then Exit(0);
   
   Result := _Len - _Num;
   
   _Len := _Num;
   SetLength(_Arr, _Len)
end;

Procedure GenericDictionary.SetStep(Const Step:sInt);
begin
   If(Step <= 0) then Exit();
   _Step := Step
end;

Constructor GenericDictionary.Create(Const DefaultVal:Tp; Const StepSize:sInt = STEP_DEFAULT);
begin
   If(StepSize <= 0)
      then _Step := STEP_DEFAULT
      else _Step := StepSize;
   
   _DefVal := DefaultVal;
   
   _Num := 0; _Len := _Step;
   SetLength(_Arr, _Len)
end;

Destructor GenericDictionary.Destroy();
begin
   SetLength(Self._Arr, 0)
end;

end.
