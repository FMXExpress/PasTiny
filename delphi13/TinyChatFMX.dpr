program TinyChatFMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  FmxChatWindow in 'FmxChatWindow.pas' {ChatForm},
  TnyNet in 'TNYNET.PAS';


begin
  Application.Initialize;
  Application.CreateForm(TChatForm, ChatForm);
  Application.Run;
end.
