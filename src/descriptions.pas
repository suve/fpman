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
      
      Summary : AnsiString;
      Declaration : AnsiString;
      Description : AnsiString;
      Errors : AnsiString;
      SeeAlso : AnsiString;
      GeneratedOn : AnsiString;
   end;


implementation

end.
