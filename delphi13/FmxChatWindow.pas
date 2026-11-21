unit FmxChatWindow;

interface

uses
  System.Classes, System.UITypes, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Layouts, FMX.Edit, FMX.StdCtrls, FMX.Memo, FMX.ScrollBox,
  FMX.Controls.Presentation, FMX.Memo.Types{$IFNDEF MSWINDOWS}, FMX.Media{$ENDIF};

type
  TChatForm = class(TForm)
    Transcript: TMemo;
    EntryBar: TLayout;
    Question: TEdit;
    AskButton: TButton;
    Voice: TCheckBox;
    procedure VoiceChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Ask(Sender: TObject);
    procedure QuestionKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: WideChar; Shift: TShiftState);
  private
    Monitor: TMemo;
    Generating: Boolean;
    {$IFNDEF MSWINDOWS}
    Player: TMediaPlayer;
    WavePath: string;
    {$ENDIF}
    procedure RefreshMonitor;
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure PlayAnswer(const Answer: string);
  public
    destructor Destroy; override;
  end;

var
  ChatForm: TChatForm;

implementation

uses
  System.SysUtils, System.IOUtils, NeuralMonitor, TnyNet,
  {$IFDEF MSWINDOWS}DesktopVoice{$ELSE}TinyVoice{$ENDIF};

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
const
  ThemeName = 'PasclawDark.style';
var
  Path, ThemePath: string;
  DarkStyle: TStyleBook;
begin
  {$IFNDEF MSWINDOWS}
  Player := TMediaPlayer.Create(Self);
  WavePath := TPath.Combine(TPath.GetTempPath, TGUID.NewGuid.ToString + '.wav');
  {$ENDIF}
  Question.MaxLength := MAXQ;
  Path := ModelPath;
  ThemePath := TPath.Combine(ExtractFilePath(Path), ThemeName);
  {$IF Defined(MSWINDOWS)}
  { RAD Studio normally builds into Win32/Debug or Win64/Release. }
  if not TFile.Exists(ThemePath) then
    ThemePath := ExpandFileName(ExtractFilePath(Path) + '..\..\styles\' + ThemeName);
  {$ENDIF}
  if TFile.Exists(ThemePath) then
  begin
    DarkStyle := TStyleBook.Create(Self);
    DarkStyle.LoadFromFile(ThemePath);
    StyleBook := DarkStyle;
  end;
  try
    OnFail := ModelError;
    Creativity := 0;
    LoadModel(Path);
    AllocMemory;
    Monitor := TMemo.Create(Self);
    Monitor.Parent := Self;
    Monitor.ReadOnly := True;
    Monitor.TabStop := False;
    Monitor.WordWrap := False;
    Monitor.Align := TAlignLayout.Right;
    if ClientWidth < 480 then begin
      Monitor.Align := TAlignLayout.Top;
      Monitor.Height := 138;
    end else Monitor.Width := 190;
    Monitor.StyledSettings := Monitor.StyledSettings - [TStyledSetting.Family];
    Monitor.TextSettings.Font.Family := 'monospace';
    Monitor.Lines.Text := MonitorText;
    OnCloseQuery := CheckClose;
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

procedure TChatForm.VoiceChange(Sender: TObject);
begin
  if Voice.IsChecked then Exit;
  {$IFDEF MSWINDOWS}
  StopVoice;
  {$ELSE}
  if Assigned(Player) then Player.Stop;
  {$ENDIF}
end;

procedure TChatForm.PlayAnswer(const Answer: string);
{$IFDEF MSWINDOWS}
begin
  PlayVoice(Answer);
{$ELSE}
var Wave: TMemoryStream;
begin
  Player.Stop;
  Player.FileName := '';
  Wave := TMemoryStream.Create;
  try
    RenderVoice(Answer, Wave);
    Wave.SaveToFile(WavePath);
  finally
    Wave.Free;
  end;
  Player.FileName := WavePath;
  Player.Play;
{$ENDIF}
end;

destructor TChatForm.Destroy;
begin
  {$IFDEF MSWINDOWS}
  StopVoice;
  {$ELSE}
  FreeAndNil(Player);
  if WavePath <> '' then DeleteFile(WavePath);
  {$ENDIF}
  inherited;
end;

procedure TChatForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not Generating;
end;

procedure TChatForm.RefreshMonitor;
begin
  Monitor.Lines.Text := MonitorText;
  Transcript.Lines[Transcript.Lines.Count-1] := GeneratedText;
  Application.ProcessMessages;
end;

procedure TChatForm.Ask(Sender: TObject);
var
  Prompt, Answer: string;
  Tenths: Longint;
begin
  if Generating then Exit;
  if Clean(Question.Text, Prompt) = 0 then Exit;
  Generating := True;
  try
    Transcript.Lines.Add('> ' + Prompt);
    Transcript.Lines.Add('...');
    BeginMonitor(RefreshMonitor);
    try
      Think(Prompt, Answer, Tenths, nil, MonitorLetter);
    finally
      EndMonitor;
    end;
    RefreshMonitor;
  finally
    Generating := False;
  end;
  Transcript.Lines.Add('');
  Transcript.GoToTextEnd;
  Question.Text := '';
  Question.SetFocus;
  if Voice.IsChecked then
    try
      PlayAnswer(Answer);
    except
      on E: Exception do Transcript.Lines.Add('Audio playback failed: ' + E.Message);
    end;
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
