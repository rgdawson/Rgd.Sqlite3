program Sqlite3_Demo;

{$IFNDEF DEBUG}
  {$WEAKLINKRTTI ON}
{$ENDIF}

uses
  Vcl.Forms,
  Demo.MainForm in 'Demo.MainForm.pas' {MainForm},
  Demo.SqliteInfoForm in 'Demo.SqliteInfoForm.pas' {SqliteInfoForm},
  Rgd.Sqlite3 in '..\..\Rgd.Sqlite3.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TSqliteInfoForm, SqliteInfoForm);
  Application.Run;
end.
