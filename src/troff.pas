unit troff;

{$INCLUDE defines.inc}


interface
   uses descriptions;

Procedure OutputTroff(Const Desc:TFunctionDesc; Var F:System.Text);


implementation
   uses SysUtils;

Procedure OutputTroff(Const Desc:TFunctionDesc; Var F:System.Text);
begin
   Writeln(F, '.\" file autogenerated by fpman');
   Writeln(F, '.TH "fp-',LowerCase(Desc.Name),'" 3 "', Desc.GeneratedOn, '" "fpman" "Free Pascal Programmer''s Manual"');
   
   Writeln(F, '.SH NAME');
   Write(F, Desc.Name);
   If(Desc.Summary <> '') then Write(F, ' - ', Desc.Summary);
   Writeln(F);
   
   If((Desc.Package_ <> '') OR (Desc.Unit_ <> '') OR (Desc.File_ <> '')) then begin
      Writeln(F, '.SH LOCATION');
      
      If(Desc.Package_ <> '') then Write(F, 'package \fB', Desc.Package_, '\fR, ');
      If(Desc.Unit_ <> '') then Write(F, 'unit \fB', Desc.Unit_, '\fR');
      
      If(Desc.File_ <> '') then begin
         Write(F,', file \fB', Desc.File_, '\fR');
         If((Desc.Line_ <> '') AND (Desc.Line_ <> '0')) then Write(F, ', line ', Desc.Line_)
      end;
      
      Writeln(F)
   end;
   
   If(Desc.Declaration <> '') then begin
      Writeln(F,'.SH SUMMARY');
      Writeln(F, Desc.Declaration);
   end;
   
   Writeln(F, '.SH DESCRIPTION');
   Writeln(F, Desc.Description);
   
   Writeln(F, '.SH ERRORS');
   Writeln(F, Desc.Errors);
   
   If(Desc.SeeAlso <> '') then begin
      Writeln(F, '.SH SEE ALSO');
      Writeln(F, Desc.SeeAlso);
   end;
   
   Writeln(F, '.SH FPMAN');
   Write(F, 'manpage autogenerated by \fBfpman\fR from ');
   If(ParamCount > 0)
      then Write(F, '\fI', ExtractFileName(ParamStr(1)), '\fR')
      else Write(F, 'STDIN');
   Writeln(F, ' on ',FormatDateTime('yyyy-mm-dd, hh:nn:ss', Now()),'.'#10);
end;

end.