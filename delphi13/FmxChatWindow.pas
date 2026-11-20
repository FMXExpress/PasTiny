unit FmxChatWindow;

interface

uses
  System.Classes, System.UITypes, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Layouts, FMX.Edit, FMX.StdCtrls, FMX.Memo, FMX.ScrollBox,
  FMX.Controls.Presentation, FMX.Memo.Types;

type
  TChatForm = class(TForm)
    Transcript: TMemo;
    EntryBar: TLayout;
    Question: TEdit;
    AskButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Ask(Sender: TObject);
    procedure QuestionKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: WideChar; Shift: TShiftState);
  end;

var
  ChatForm: TChatForm;

implementation

uses
  System.SysUtils, System.IOUtils, TnyNet;

{$R *.fmx}

function ModelPath: string;
begin
  {$IF Defined(ANDROID) or Defined(IOS)}
  Result := TPath.Combine(TPath.GetDocumentsPath, 'TINY.BIN');
  {$ELSEIF Defined(MACOS)}
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '../Resources/TINY.BIN');
  {$ELSE}
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'TINY.BIN');
  {$ENDIF}
end;

procedure ModelError(const Msg: string);
begin
  raise Exception.Create(Msg);
end;

procedure TChatForm.FormCreate(Sender: TObject);
var
  Path: string;
begin
  Question.MaxLength := MAXQ;
  Path := ModelPath;
  try
    OnFail := ModelError;
    Creativity := 0;
    LoadModel(Path);
    AllocMemory;
  except
    on E: Exception do
    begin
      Question.Enabled := False;
      AskButton.Enabled := False;
      Transcript.Lines.Add('Could not load the model at ' + Path);
      Transcript.Lines.Add(E.Message);
    end;
  end;
end;

procedure TChatForm.Ask(Sender: TObject);
var
  Prompt, Answer: string;
  Tenths: Longint;
begin
  if Clean(Question.Text, Prompt) = 0 then Exit;
  Think(Prompt, Answer, Tenths, nil, nil);
  Transcript.Lines.Add('> ' + Prompt);
  Transcript.Lines.Add(Answer);
  Transcript.Lines.Add('');
  Transcript.GoToTextEnd;
  Question.Text := '';
  Question.SetFocus;
end;

procedure TChatForm.QuestionKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Key = vkReturn) or (KeyChar = #13) then
  begin
    Key := 0;
    KeyChar := #0;
    Ask(Sender);
  end;
end;

end.
