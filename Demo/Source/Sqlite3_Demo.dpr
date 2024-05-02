program Sqlite3_Demo;

uses
  Vcl.Forms,
  Demo.MainForm in 'Demo.MainForm.pas' {MainForm},
  Rgd.Sqlite3 in '..\..\Rgd.Sqlite3.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
