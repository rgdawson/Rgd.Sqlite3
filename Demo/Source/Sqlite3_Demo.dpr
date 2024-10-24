program Sqlite3_Demo;

uses
  Vcl.Forms,
  Demo.MainForm in 'Demo.MainForm.pas' {MainForm},
  Demo.SqliteInfoForm in 'Demo.SqliteInfoForm.pas' {SqliteInfoForm};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TSqliteInfoForm, SqliteInfoForm);
  Application.Run;
end.
