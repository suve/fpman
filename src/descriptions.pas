unit descriptions;

{$INCLUDE defines.inc}


interface

Type
   PFunctionDesc = ^TFunctionDesc;
   TFunctionDesc = record
      Name : AnsiString;
      Unit_ : AnsiString;
      Package_ : AnsiString;
      File_ : AnsiString;
      Line_ : AnsiString;
      Classifiers : AnsiString;
      
      Summary : AnsiString;
      Declaration : AnsiString;
      Inheritance : AnsiString;
      
      Description : AnsiString;
      Errors : AnsiString;
      SeeAlso : AnsiString;
      GeneratedOn : AnsiString;
   end;

Procedure ResetDesc(Out Desc:TFunctionDesc);


implementation

Procedure ResetDesc(Out Desc:TFunctionDesc);
begin
   Desc.Name := '';
   Desc.Unit_ := '';
   Desc.Package_ := '';
   Desc.File_ := '';
   Desc.Line_ := '';
   Desc.Classifiers := '';
   
   Desc.Summary := '';
   Desc.Declaration := '';
   Desc.Inheritance := '';
   
   Desc.Description := '';
   Desc.Errors := '';
   Desc.SeeAlso := '';
   Desc.GeneratedOn := ''
end;

end.
