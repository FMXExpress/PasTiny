program TinyChat;

uses
  System.SysUtils, Vcl.Forms, Vcl.Dialogs,
  ChatWindow in 'ChatWindow.pas',
  TnyNet in 'TNYNET.PAS';

procedure ModelError(const Msg: string);
begin
  raise Exception.Create(Msg);
end;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'PasTiny';
  try
    Creativity := 0;
    OnFail := ModelError;
    LoadModel(ExtractFilePath(ParamStr(0)) + 'TINY.BIN');
    AllocMemory;
    Application.CreateForm(TChatWindow, Chat);
    Application.Run;
  except
    on E: Exception do begin
      ShowMessage(E.Message);
      ExitCode := 1;
    end;
  end;
end.
