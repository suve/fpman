unit descriptions;

{$INCLUDE defines.inc}


interface

Type
   PPageSummary = ^TPageSummary;
   TPageSummary = record
      Name : AnsiString;
      Unit_ : AnsiString;
      Package_ : AnsiString;
   end;
   
   PPageDescription = ^TPageDescription;
   TPageDescription = record
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

Procedure ResetDesc(Out Desc:TPageDescription);
Function Summarize(Const Desc:TPageDescription):TPageSummary;


implementation

Procedure ResetDesc(Out Desc:TPageDescription);
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

Function Summarize(Const Desc:TPageDescription):TPageSummary;
begin
   Result.Name := Desc.Name;
   Result.Unit_ := Desc.Unit_;
   Result.Package_ := Desc.Package_
end;

end.
