program WebMConvert;

uses
  Vcl.Forms,
  main in 'main.pas' {FrmWebMConverter},
  K.Translate in 'D:\Component\KLib\K.Translate.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmWebMConverter, FrmWebMConverter);
  Application.Run;
end.
