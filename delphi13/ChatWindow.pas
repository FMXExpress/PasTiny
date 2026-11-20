unit ChatWindow;

interface

uses
  System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TChatWindow = class(TForm)
  private
    Monitor: TMemo;
    Generating: Boolean;
    AnswerStart: Integer;
    procedure RefreshMonitor;
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    History: TMemo;
    Question: TEdit;
    Voice: TCheckBox;
    procedure VoiceClick(Sender: TObject);
    procedure Ask(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  Chat: TChatWindow;

implementation

uses NeuralMonitor, Vcl.Graphics, TnyNet, DesktopVoice;

constructor TChatWindow.Create(AOwner: TComponent);
var
  Entry: TPanel;
  Send: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := 'PasTiny';
  Position := poScreenCenter;
  ClientWidth := 640;
  ClientHeight := 400;

  Entry := TPanel.Create(Self);
  Entry.Parent := Self;
  Entry.Align := alBottom;
  Entry.Height := 38;
  Entry.BevelOuter := bvNone;

  Send := TButton.Create(Self);
  Send.Parent := Entry;
  Send.Align := alRight;
  Send.Caption := 'Ask';
  Send.Default := True;
  Send.OnClick := Ask;

  Voice := TCheckBox.Create(Self);
  Voice.Parent := Entry;
  Voice.Align := alLeft;
  Voice.Caption := 'Sound';
  Voice.Width := 68;
  Voice.Checked := True;
  Voice.OnClick := VoiceClick;

  Question := TEdit.Create(Self);
  Question.Parent := Entry;
  Question.Align := alClient;
  Question.TextHint := 'Ask a question';
  Question.MaxLength := MAXQ;

  History := TMemo.Create(Self);
  History.Parent := Self;
  History.Align := alClient;
  History.ReadOnly := True;
  History.ScrollBars := ssVertical;
  History.TabStop := False;
  ActiveControl := Question;
  Monitor := TMemo.Create(Self);
  Monitor.Parent := Self;
  Monitor.ReadOnly := True;
  Monitor.TabStop := False;
  Monitor.WordWrap := False;
  Monitor.Align := alRight;
  Monitor.Width := 215;
  Monitor.Font.Name := 'Consolas';
  Monitor.Color := $00251B12;
  Monitor.Font.Color := $00B6FF88;
  History.Font.Name := 'Consolas';
  Monitor.Lines.Text := MonitorText;
  OnCloseQuery := CheckClose;
end;

procedure TChatWindow.VoiceClick(Sender: TObject);
begin
  if not Voice.Checked then StopVoice;
end;

procedure TChatWindow.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not Generating;
end;

procedure TChatWindow.RefreshMonitor;
begin
  Monitor.Lines.Text := MonitorText;
  History.SelStart := AnswerStart;
  History.SelLength := History.GetTextLen - AnswerStart;
  History.SelText := GeneratedText;
  Application.ProcessMessages;
end;

procedure TChatWindow.Ask(Sender: TObject);
var
  Q, Answer: string;
  Tenths: Longint;
begin
  if Generating then Exit;
  if Clean(Question.Text, Q) = 0 then Exit;
  Generating := True;
  try
    History.Lines.Add('> ' + Q);
    AnswerStart := History.GetTextLen;
    BeginMonitor(RefreshMonitor);
    try
      Think(Q, Answer, Tenths, nil, MonitorLetter);
    finally
      EndMonitor;
    end;
    RefreshMonitor;
  finally
    Generating := False;
  end;
  History.Lines.Add('');
  Question.Clear;
  Question.SetFocus;
  if Voice.Checked then PlayVoice(Answer);
end;

end.
