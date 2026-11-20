unit ChatWindow;

interface

uses
  System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TChatWindow = class(TForm)
  private
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

uses TnyNet, DesktopVoice;

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
end;

procedure TChatWindow.VoiceClick(Sender: TObject);
begin
  if not Voice.Checked then StopVoice;
end;

procedure TChatWindow.Ask(Sender: TObject);
var
  Q, Answer: string;
  Tenths: Longint;
begin
  if Clean(Question.Text, Q) = 0 then Exit;
  Think(Q, Answer, Tenths, nil, nil);
  History.Lines.Add('> ' + Q);
  History.Lines.Add(Answer);
  History.Lines.Add('');
  Question.Clear;
  Question.SetFocus;
  if Voice.Checked then PlayVoice(Answer);
end;

end.
