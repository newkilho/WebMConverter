program WebMConvert;

uses
  Vcl.Forms,
  main in 'main.pas' {FrmWebMConverter};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmWebMConverter, FrmWebMConverter);
  Application.Run;
end.
