unit ChatWindow;

interface

uses
  System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TChatWindow = class(TForm)
  private
    History: TMemo;
    Question: TEdit;
    procedure Ask(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  Chat: TChatWindow;

implementation

uses TnyNet;

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
end;

end.
