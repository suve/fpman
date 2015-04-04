unit dynarray;

{$INCLUDE defines.inc}

interface

Type
   Generic GenericDynArray<Tp> = object
      Protected
         Type
         DisposeProc = Procedure(Item : Tp);
         TypeArray = Array of Tp;
         
         Var
         _Len, _Num, _Step : sInt;
         _Arr : Array of Tp;
         
         Function  ReadItem(Const Idx: sInt):Tp;
         Procedure WriteItem(Const Idx: sInt; Const Value: Tp);
         
         Procedure SetStep(Const Step:sInt);
      
      Public
         Function Purge():sInt;
         Function Purge(Const FreeItem : DisposeProc):sInt;
         
         Function  Trim():sInt;
         Procedure Push(Const Value:Tp);
         
         Property Count: sInt read _Num;
         Property Size: sInt read _Len;
         
         Property Step: sInt read _Step write SetStep;
         
         Property Item[Idx: sInt]: Tp read ReadItem write WriteItem; Default;
         Property Arr : TypeArray read _Arr;
         
         {$DEFINE STEP_DEFAULT := 8}
         Constructor Create(Const ResizeStep : sInt = STEP_DEFAULT);
         Destructor Destroy();
   end;


implementation

Function GenericDynArray.ReadItem(Const Idx: sInt):Tp;
begin
   Result := _Arr[Idx]
end;

Procedure GenericDynArray.WriteItem(Const Idx: sInt; Const Value: Tp);
begin
   _Arr[Idx] := Value
end;

Function GenericDynArray.Purge():sInt;
begin
   Result := _Num;
   _Num := 0
end;

Function GenericDynArray.Purge(Const FreeItem : DisposeProc):sInt;
Var
   Idx : sInt;
begin
   Result := _Num;

   For Idx := 0 to (_Num - 1) do FreeItem(_Arr[Idx]);
   _Num := 0
end;

Function GenericDynArray.Trim():sInt;
begin
   If(_Len = _Num) then Exit(0);
   
   Result := _Len - _Num;
   
   _Len := _Num;
   SetLength(_Arr, _Len)
end;

Procedure GenericDynArray.Push(Const Value:Tp);
begin
   If(_Len <= _Num) then begin
      _Len += _Step;
      SetLength(_Arr, _Len)
   end;
   _Arr[_Num] := Value;
   _Num += 1
end;

Procedure GenericDynArray.SetStep(Const Step:sInt);
begin
   If(Step <= 0) then Exit();
   _Step := Step
end;

Constructor GenericDynArray.Create(Const ResizeStep : sInt = STEP_DEFAULT);
begin
   If(ResizeStep <= 0)
      then _Step := STEP_DEFAULT
      else _Step := ResizeStep;
   
   _Len := 0; _Num := 0;
   SetLength(_Arr, 0)
end;

Destructor GenericDynArray.Destroy();
begin
   SetLength(_Arr, 0)
end;

end.
