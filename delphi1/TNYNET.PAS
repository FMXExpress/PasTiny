{$IFNDEF TINYMODERN}unit TnyNet;{$ENDIF}

(* TINY 2.1 for Delphi 1 - the neural network.

   A port of the network part of TINY.C (Turbo C 2.0, by WollyMonjac).
   It reads the unchanged TINY.BIN and answers one letter at a time.

   Two engines, chosen with UseInt before the network is loaded:
     integer engine (default) - whole numbers only: no coprocessor and no
                                emulator is used while it thinks
     float engine (/FLOAT)    - the original all-float code, for comparison

   Plain Object Pascal with no units, so the same file also compiles with
   Free Pascal ({$MODE TP}) for automated tests on a modern machine.
   Under Delphi 1 (VER80) the two inner loops are 8086 assembler. *)

{$IFDEF FPC}
  {$IFDEF TINYMODERN}{$MODE DELPHIUNICODE}{$ELSE}{$MODE TP}{$ENDIF}
{$ENDIF}
{$IFDEF TINYMODERN}{$R-,X+}{$ELSE}{$F+,R-,S-,X+}{$ENDIF}

interface

const
  VOCAB  = 97;     { 0 end, 1 newline, 2.. the letters ' '..'~' }
  CTX    = 128;    { longest question + answer, in letters      }
  MAXD   = 128;
  MAXHID = 512;
  MAXL   = 8;
  MAXQ   = 72;     { longest question, in letters }
  NBENCH = 5;

type
  PS8Arr   = ^TS8Arr;
  TS8Arr   = array[0..65000] of ShortInt;
  PSglArr  = ^TSglArr;
  TSglArr  = array[0..16000] of Single;
  TQuantValue = {$IFDEF TINYMODERN}SmallInt{$ELSE}Integer{$ENDIF};
  TReadCount = {$IFDEF TINYMODERN}Longint{$ELSE}Word{$ENDIF};
  PI16Arr  = ^TI16Arr;
  TI16Arr  = array[0..32000] of TQuantValue;
  PLongArr = ^TLongArr;
  TLongArr = array[0..16000] of Longint;

  TTable = record
    Scale: PSglArr;
    W: PS8Arr;
    Rows, Cols: Integer;
  end;

  TFailProc   = procedure(const Msg: String);
  TLoadProc   = procedure(Done, Total: Integer);
  TStepProc   = procedure(I, N: Integer);
  TLetterProc = procedure(C: Integer);
  TClockFunc  = function: Longint;          { milliseconds }
  TIdleProc   = procedure;

var
  D, L, H, HD, HID: Integer;
  LayerAct: array[0..MAXL - 1] of Single;   { how busy each layer was }
  Score: array[0..VOCAB - 1] of Single;
  Creativity: Integer;                      { 0 surest .. 9 wild }
  LastConf: Single;                         { how sure of the last letter }
  (* The same two as whole numbers, set by both engines: the interface
     reads these, so that it needs no floating point either. *)
  LastMil: Integer;                         { sureness in thousandths }
  LayerLvl: array[0..MAXL - 1] of Longint;  { busyness in 256ths }
  UseInt: Boolean;                          { integer engine? set before LoadModel }
  AbortThink: Boolean;                      { set to stop think() early }
  OnFail: TFailProc;                        { nil: write to Output, Halt }
  OnLoad: TLoadProc;                        { loading progress, may be nil }
  ClockMs: TClockFunc;                      { may be nil (times are 0) }
  {$IFDEF TINYMODERN}OnAnswer: procedure(const Answer: String);{$ENDIF}
  OnIdle: TIdleProc;                        { called once per letter }

const
  BenchQ: array[1..NBENCH] of String[40] = (
    'what is the capital of peru', 'is a whale a fish', 'what is 7 times 8',
    'which countries border estonia', 'spell elephant');

procedure Fail(const Msg: String);
procedure LoadModel(const Name: String);
procedure AllocMemory;
function Think(const Q: String; var Answer: String; var Tenths: Longint;
  OnStep: TStepProc; OnLetter: TLetterProc): Integer;
function Clean(const Line: String; var Q: String): Integer;
function IsWord(const Q, W: String): Boolean;
function NumStr(N: Longint): String;
function TenthsStr(T: Longint): String;
procedure PlainRun(var Fin, Fout: Text);
procedure RunBench(var Fout: Text; const Build: String; Fpu: Integer);

implementation

var
  AttDiv: Single;
  Emb, PosT: TTable;
  WQ, WK, WV, WO, F1, F2: array[0..MAXL - 1] of TTable;
  G1, G2: array[0..MAXL - 1] of PSglArr;
  GF: PSglArr;
  TablesDone, TablesTotal: Integer;
  ModelFile: file;

  (* Memory of earlier letters: for every layer and position, the key and
     value lists of D numbers, kept as bytes with one scale per list. *)
  KC, VC: array[0..MAXL - 1] of PS8Arr;
  KS, VS: array[0..MAXL - 1] of PSglArr;

  { work buffers }
  BX, BH, BQ, BT, BA: array[0..MAXD - 1] of Single;
  BM: array[0..MAXHID - 1] of Single;
  BS: array[0..CTX - 1] of Single;

  { integer engine }
  XQ: array[0..MAXHID - 1] of TQuantValue;      { input vector as 16-bit }
  QQ: array[0..MAXD - 1] of TQuantValue;        { query as 16-bit }
  WW: array[0..CTX - 1] of TQuantValue;         { attention weights, 16-bit }
  EE: array[0..CTX - 1] of Longint;
  VMax: array[0..MAXL - 1] of Longint;      { largest value scale so far }
  Fixed: Boolean;                           { the tables are in integer form }
  SqrtD: Longint;
  AttM: Word;
  AttSh: Integer;

type
  (* A row's scale in the integer engine: scale = M / 2^Sh.  It takes the
     place of the 4-byte floating point number read from the file. *)
  TScale = packed record
    M: Word;
    Sh: TQuantValue;
  end;
  PScaleArr = ^TScaleArr;
  TScaleArr = array[0..16000] of TScale;

const
  { exp(-k/128) * 32767, for k = 0..1535 }
  ExpTab: array[0..1535] of TQuantValue = (
    32767, 32512, 32259, 32008, 31759, 31512, 31266, 31023, 30782, 30542, 30305, 30069,
    29835, 29603, 29372, 29144, 28917, 28692, 28468, 28247, 28027, 27809, 27593, 27378,
    27165, 26953, 26744, 26536, 26329, 26124, 25921, 25719, 25519, 25320, 25123, 24928,
    24734, 24541, 24350, 24161, 23973, 23786, 23601, 23418, 23235, 23054, 22875, 22697,
    22520, 22345, 22171, 21999, 21828, 21658, 21489, 21322, 21156, 20991, 20828, 20666,
    20505, 20345, 20187, 20030, 19874, 19720, 19566, 19414, 19263, 19113, 18964, 18817,
    18670, 18525, 18381, 18238, 18096, 17955, 17815, 17676, 17539, 17402, 17267, 17133,
    16999, 16867, 16736, 16606, 16476, 16348, 16221, 16095, 15969, 15845, 15722, 15599,
    15478, 15358, 15238, 15119, 15002, 14885, 14769, 14654, 14540, 14427, 14315, 14203,
    14093, 13983, 13874, 13766, 13659, 13553, 13448, 13343, 13239, 13136, 13034, 12932,
    12832, 12732, 12633, 12534, 12437, 12340, 12244, 12149, 12054, 11960, 11867, 11775,
    11683, 11593, 11502, 11413, 11324, 11236, 11148, 11062, 10976, 10890, 10805, 10721,
    10638, 10555, 10473, 10391, 10311, 10230, 10151, 10072, 9993, 9916, 9838, 9762,
    9686, 9611, 9536, 9462, 9388, 9315, 9242, 9170, 9099, 9028, 8958, 8888,
    8819, 8750, 8682, 8615, 8548, 8481, 8415, 8350, 8285, 8220, 8156, 8093,
    8030, 7967, 7905, 7844, 7783, 7722, 7662, 7603, 7543, 7485, 7426, 7369,
    7311, 7254, 7198, 7142, 7086, 7031, 6976, 6922, 6868, 6815, 6762, 6709,
    6657, 6605, 6554, 6503, 6452, 6402, 6352, 6303, 6254, 6205, 6157, 6109,
    6061, 6014, 5967, 5921, 5875, 5829, 5784, 5739, 5694, 5650, 5606, 5562,
    5519, 5476, 5433, 5391, 5349, 5307, 5266, 5225, 5184, 5144, 5104, 5064,
    5025, 4986, 4947, 4909, 4870, 4832, 4795, 4758, 4721, 4684, 4647, 4611,
    4575, 4540, 4504, 4469, 4435, 4400, 4366, 4332, 4298, 4265, 4231, 4199,
    4166, 4133, 4101, 4069, 4038, 4006, 3975, 3944, 3913, 3883, 3853, 3823,
    3793, 3764, 3734, 3705, 3676, 3648, 3619, 3591, 3563, 3536, 3508, 3481,
    3454, 3427, 3400, 3374, 3347, 3321, 3295, 3270, 3244, 3219, 3194, 3169,
    3145, 3120, 3096, 3072, 3048, 3024, 3001, 2977, 2954, 2931, 2908, 2886,
    2863, 2841, 2819, 2797, 2775, 2753, 2732, 2711, 2690, 2669, 2648, 2627,
    2607, 2587, 2567, 2547, 2527, 2507, 2488, 2468, 2449, 2430, 2411, 2392,
    2374, 2355, 2337, 2319, 2301, 2283, 2265, 2247, 2230, 2212, 2195, 2178,
    2161, 2144, 2128, 2111, 2095, 2078, 2062, 2046, 2030, 2014, 1999, 1983,
    1968, 1952, 1937, 1922, 1907, 1892, 1878, 1863, 1849, 1834, 1820, 1806,
    1792, 1778, 1764, 1750, 1737, 1723, 1710, 1696, 1683, 1670, 1657, 1644,
    1631, 1619, 1606, 1594, 1581, 1569, 1557, 1545, 1533, 1521, 1509, 1497,
    1485, 1474, 1462, 1451, 1440, 1428, 1417, 1406, 1395, 1385, 1374, 1363,
    1352, 1342, 1331, 1321, 1311, 1301, 1291, 1280, 1271, 1261, 1251, 1241,
    1231, 1222, 1212, 1203, 1194, 1184, 1175, 1166, 1157, 1148, 1139, 1130,
    1121, 1112, 1104, 1095, 1087, 1078, 1070, 1062, 1053, 1045, 1037, 1029,
    1021, 1013, 1005, 997, 989, 982, 974, 967, 959, 952, 944, 937,
    930, 922, 915, 908, 901, 894, 887, 880, 873, 866, 860, 853,
    846, 840, 833, 827, 820, 814, 808, 801, 795, 789, 783, 777,
    771, 765, 759, 753, 747, 741, 735, 730, 724, 718, 713, 707,
    702, 696, 691, 685, 680, 675, 670, 664, 659, 654, 649, 644,
    639, 634, 629, 624, 619, 614, 610, 605, 600, 595, 591, 586,
    582, 577, 573, 568, 564, 559, 555, 551, 546, 542, 538, 534,
    530, 526, 521, 517, 513, 509, 505, 501, 498, 494, 490, 486,
    482, 478, 475, 471, 467, 464, 460, 457, 453, 449, 446, 443,
    439, 436, 432, 429, 426, 422, 419, 416, 412, 409, 406, 403,
    400, 397, 394, 391, 387, 384, 381, 379, 376, 373, 370, 367,
    364, 361, 358, 356, 353, 350, 347, 345, 342, 339, 337, 334,
    331, 329, 326, 324, 321, 319, 316, 314, 311, 309, 307, 304,
    302, 299, 297, 295, 292, 290, 288, 286, 283, 281, 279, 277,
    275, 273, 271, 268, 266, 264, 262, 260, 258, 256, 254, 252,
    250, 248, 246, 244, 242, 241, 239, 237, 235, 233, 231, 230,
    228, 226, 224, 223, 221, 219, 217, 216, 214, 212, 211, 209,
    207, 206, 204, 203, 201, 199, 198, 196, 195, 193, 192, 190,
    189, 187, 186, 184, 183, 182, 180, 179, 177, 176, 175, 173,
    172, 171, 169, 168, 167, 165, 164, 163, 162, 160, 159, 158,
    157, 155, 154, 153, 152, 151, 149, 148, 147, 146, 145, 144,
    143, 141, 140, 139, 138, 137, 136, 135, 134, 133, 132, 131,
    130, 129, 128, 127, 126, 125, 124, 123, 122, 121, 120, 119,
    118, 117, 116, 115, 115, 114, 113, 112, 111, 110, 109, 108,
    108, 107, 106, 105, 104, 103, 103, 102, 101, 100, 100, 99,
    98, 97, 96, 96, 95, 94, 93, 93, 92, 91, 91, 90,
    89, 89, 88, 87, 86, 86, 85, 84, 84, 83, 83, 82,
    81, 81, 80, 79, 79, 78, 78, 77, 76, 76, 75, 75,
    74, 73, 73, 72, 72, 71, 71, 70, 69, 69, 68, 68,
    67, 67, 66, 66, 65, 65, 64, 64, 63, 63, 62, 62,
    61, 61, 60, 60, 59, 59, 59, 58, 58, 57, 57, 56,
    56, 55, 55, 55, 54, 54, 53, 53, 52, 52, 52, 51,
    51, 50, 50, 50, 49, 49, 48, 48, 48, 47, 47, 47,
    46, 46, 46, 45, 45, 45, 44, 44, 43, 43, 43, 42,
    42, 42, 41, 41, 41, 41, 40, 40, 40, 39, 39, 39,
    38, 38, 38, 37, 37, 37, 37, 36, 36, 36, 35, 35,
    35, 35, 34, 34, 34, 34, 33, 33, 33, 33, 32, 32,
    32, 32, 31, 31, 31, 31, 30, 30, 30, 30, 29, 29,
    29, 29, 29, 28, 28, 28, 28, 27, 27, 27, 27, 27,
    26, 26, 26, 26, 26, 25, 25, 25, 25, 25, 24, 24,
    24, 24, 24, 23, 23, 23, 23, 23, 23, 22, 22, 22,
    22, 22, 22, 21, 21, 21, 21, 21, 21, 20, 20, 20,
    20, 20, 20, 19, 19, 19, 19, 19, 19, 19, 18, 18,
    18, 18, 18, 18, 18, 17, 17, 17, 17, 17, 17, 17,
    17, 16, 16, 16, 16, 16, 16, 16, 16, 15, 15, 15,
    15, 15, 15, 15, 15, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 11,
    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 10, 10,
    10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9,
    9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
    9, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
    8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    4, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

{ ---- errors and loading ------------------------------------------- }

procedure Fail(const Msg: String);
begin
  if Assigned(OnFail) then
    OnFail(Msg);
  WriteLn;
  WriteLn('TINY: ', Msg);
  Halt(1);
end;

procedure Damaged;
begin
  Fail('TINY.BIN is too short or damaged.');
end;

function GetMemory(N: Word): Pointer;
var
  P: Pointer;
begin
  GetMem(P, N);
  if P = nil then
    Fail('not enough memory.');
  GetMemory := P;
end;

procedure ReadBytes(var Buf; N: Word);
var
  Got: TReadCount;
begin
  {$I-}
  BlockRead(ModelFile, Buf, N, Got);
  {$I+}
  if (IOResult <> 0) or (Got <> N) then
    Damaged;
end;

function Read16: Integer;
var
  B: array[0..1] of Byte;
begin
  ReadBytes(B, 2);
  Read16 := Integer(Word(B[0]) or (Word(B[1]) shl 8));
end;

procedure LoadTable(var T: TTable; Rows, Cols: Integer);
var
  R: Integer;
begin
  T.Rows := Rows;
  T.Cols := Cols;
  if Longint(Rows) * Cols > 65000 then
    Fail('a table in TINY.BIN is too big.');
  T.Scale := GetMemory(Word(Rows) * 4);
  T.W := GetMemory(Word(Longint(Rows) * Cols));
  for R := 0 to Rows - 1 do
  begin
    ReadBytes(T.Scale^[R], 4);
    ReadBytes(T.W^[Word(Longint(R) * Cols)], Cols);
  end;
  Inc(TablesDone);
  if Assigned(OnLoad) then
    OnLoad(TablesDone, TablesTotal);
end;

function LoadGains: PSglArr;
var
  G: PSglArr;
begin
  G := GetMemory(Word(D) * 4);
  ReadBytes(G^, Word(D) * 4);
  LoadGains := G;
end;

procedure FixModel; forward;

procedure LoadModel(const Name: String);
var
  Magic: array[0..3] of Byte;
  I, Code: Integer;
  B: Byte;
  Got: TReadCount;
begin
  if SizeOf(Single) <> 4 then
    Fail('this compiler has an unusual Single size.');
  {$IFDEF TINYMODERN}AssignFile{$ELSE}Assign{$ENDIF}(ModelFile, Name);
  FileMode := 0;
  {$I-}
  Reset(ModelFile, 1);
  {$I+}
  if IOResult <> 0 then
    Fail('cannot open TINY.BIN. Keep it in the same directory as TINY.EXE.');
  {$I-}
  BlockRead(ModelFile, Magic, 4, Got);
  {$I+}
  Code := IOResult;
  if (Code <> 0) or (Got <> 4) or (Magic[0] <> Ord('T')) or (Magic[1] <> Ord('N')) or
     (Magic[2] <> Ord('Y')) or (Magic[3] <> Ord('2')) then
    Fail('TINY.BIN is not a version 2 network file.');
  D := Read16; L := Read16; H := Read16; HID := Read16;
  if (D < 8) or (D > MAXD) or (L < 1) or (L > MAXL) or (H < 1) or
     (D mod H <> 0) or (HID < 8) or (HID > MAXHID) then
    Fail('TINY.BIN has a network size this program cannot handle.');
  HD := D div H;
  TablesDone := 0;
  TablesTotal := 2 + 6 * L;
  Fixed := UseInt;
  if not Fixed then AttDiv := Sqrt(HD);
  LoadTable(Emb, VOCAB, D);
  LoadTable(PosT, CTX, D);
  for I := 0 to L - 1 do
  begin
    G1[I] := LoadGains;
    LoadTable(WQ[I], D, D);
    LoadTable(WK[I], D, D);
    LoadTable(WV[I], D, D);
    LoadTable(WO[I], D, D);
    G2[I] := LoadGains;
    LoadTable(F1[I], HID, D);
    LoadTable(F2[I], D, HID);
  end;
  GF := LoadGains;
  {$I-}
  BlockRead(ModelFile, B, 1, Got);
  {$I+}
  Code := IOResult;
  if (Code <> 0) or (Got <> 0) then
    Fail('TINY.BIN has the wrong size.');
  {$IFDEF TINYMODERN}CloseFile{$ELSE}Close{$ENDIF}(ModelFile);
  if Fixed then FixModel;
end;

procedure AllocMemory;
var
  I: Integer;
begin
  for I := 0 to L - 1 do
  begin
    KC[I] := GetMemory(Word(CTX) * Word(D));
    VC[I] := GetMemory(Word(CTX) * Word(D));
    KS[I] := GetMemory(CTX * 4);
    VS[I] := GetMemory(CTX * 4);
  end;
end;

{ ---- integer kernels -------------------------------------------------- }

{$IFDEF VER80}
{$DEFINE TINYASM}
{$ENDIF}
{$IFDEF NOASM}
{$UNDEF TINYASM}
{$ENDIF}

{$IFDEF TINYASM}

(* Sum of W[i] * X[i] for i = 0..N-1: 8-bit times 16-bit, 32-bit sum.
   8086 code: IMUL gives the 32-bit product in DX:AX. *)
function DotS8I16(W, X: Pointer; N: Integer): Longint; assembler;
asm
        push  ds
        mov   cx, N
        lds   si, W
        les   di, X
        push  bp
        xor   bx, bx
        xor   bp, bp
        jcxz  @done
@again:
        lodsb
        cbw
        imul  word ptr es:[di]
        add   bx, ax
        adc   bp, dx
        add   di, 2
        loop  @again
@done:
        mov   ax, bx
        mov   dx, bp
        pop   bp
        pop   ds
end;

(* A * M / 2^Sh, rounded, the 48-bit product kept whole in between.
   Sh of 0 or less: no shift. *)
function MulShr(A: Longint; M: Word; Sh: Integer): Longint; assembler;
asm
        mov   ax, word ptr A
        mov   dx, word ptr A+2
        mov   di, dx
        or    dx, dx
        jns   @pos
        neg   dx
        neg   ax
        sbb   dx, 0
@pos:
        mov   cx, dx
        mul   word ptr M
        mov   bx, ax
        mov   si, dx
        mov   ax, cx
        mul   word ptr M
        add   si, ax
        adc   dx, 0
        mov   cx, Sh
        or    cx, cx
        jle   @sign
        dec   cx
@words:
        cmp   cx, 16
        jb    @bits
        mov   bx, si
        mov   si, dx
        xor   dx, dx
        sub   cx, 16
        jmp   @words
@bits:
        jcxz  @round
@bit:
        shr   dx, 1
        rcr   si, 1
        rcr   bx, 1
        loop  @bit
@round:
        add   bx, 1
        adc   si, 0
        adc   dx, 0
        shr   dx, 1
        rcr   si, 1
        rcr   bx, 1
@sign:
        mov   ax, bx
        mov   dx, si
        or    di, di
        jns   @out
        neg   dx
        neg   ax
        sbb   dx, 0
@out:
end;

(* The sum of N products of a byte, every Stride bytes from V on, and a
   16-bit number. *)
function DotStride(V: Pointer; Stride: Word; W: Pointer; N: Word): Longint; assembler;
var
  Hi: Word;
asm
        push  ds
        mov   Hi, 0
        xor   bx, bx
        mov   cx, N
        lds   si, V
        les   di, W
        jcxz  @done
@again:
        mov   al, [si]
        cbw
        imul  word ptr es:[di]
        add   bx, ax
        adc   Hi, dx
        add   si, Stride
        add   di, 2
        loop  @again
@done:
        pop   ds
        mov   ax, bx
        mov   dx, Hi
end;

{$ELSE}

function DotS8I16(W, X: Pointer; N: Integer): Longint;
var
  I: Integer;
  S: Longint;
begin
  S := 0;
  for I := 0 to N - 1 do
    S := S + Longint(PS8Arr(W)^[I]) * PI16Arr(X)^[I];
  DotS8I16 := S;
end;

(* A * M / 2^Sh, rounded.  The product can take 48 bits, so it is built
   from pieces that each fit a Longint: its top 32 bits in PH and its
   bottom 16 in PL.  Sh of 0 or less: no shift. *)
function MulShr(A: Longint; M: Word; Sh: Integer): Longint;
var
  U, X, PH, PL, R: Longint;
begin
  U := Abs(A);
  X := (U and $FF) * M + (((U shr 8) and $FF) * M and $FF) shl 8;
  PL := X and $FFFF;
  PH := (U shr 16) * M + (((U shr 8) and $FF) * M) shr 8 + X shr 16;
  if Sh <= 0 then R := PH shl 16 + PL
  else if Sh < 16 then R := PH shl (16 - Sh) + (PL + Longint(1) shl (Sh - 1)) shr Sh
  else if Sh = 16 then R := PH + PL shr 15
  else if Sh < 48 then R := (PH + Longint(1) shl (Sh - 17)) shr (Sh - 16)
  else R := 0;
  if A < 0 then MulShr := -R else MulShr := R;
end;

function DotStride(V: Pointer; Stride: Word; W: Pointer; N: Word): Longint;
var
  J: Integer;
  S: Longint;
begin
  S := 0;
  for J := 0 to Integer(N) - 1 do
    S := S + Longint(PS8Arr(V)^[Word(Longint(J) * Stride)]) * PI16Arr(W)^[J];
  DotStride := S;
end;

{$ENDIF}

{ ---- the network ------------------------------------------------------ }

{ ---- the float engine ----------------------------------------------- }

{ Y = table * X }
procedure MatVec(const T: TTable; X, Y: PSglArr);
var
  R, C, Cols: Integer;
  Off: Word;
  S: Single;
begin
  Cols := T.Cols;
  for R := 0 to T.Rows - 1 do
  begin
    Off := Word(Longint(R) * Cols);
    S := 0;
    for C := 0 to Cols - 1 do
      S := S + T.W^[Off + Word(C)] * X^[C];
    Y^[R] := S * T.Scale^[R];
  end;
end;

{ Y = X scaled to a standard size, times the gains G }
procedure Norm(X, G, Y: PSglArr);
var
  I: Integer;
  S: Single;
begin
  S := 0;
  for I := 0 to D - 1 do
    S := S + X^[I] * X^[I];
  S := 1.0 / Sqrt(S / D + 1E-5);
  for I := 0 to D - 1 do
    Y^[I] := X^[I] * S * G^[I];
end;

{ e to the power X, quietly 0 for very negative X }
function SafeExp(X: Single): Single;
begin
  if X < -60.0 then
    SafeExp := 0
  else
    SafeExp := Exp(X);
end;

{ keep a list of D numbers as bytes, returning the scale }
function Store(Dst: PS8Arr; Src: PSglArr): Single;
var
  I: Integer;
  Big, V, K: Single;
begin
  Big := 0;
  for I := 0 to D - 1 do
  begin
    V := Abs(Src^[I]);
    if V > Big then Big := V;
  end;
  if Big < 1E-20 then
    Big := 1E-20;
  K := 127.0 / Big;
  for I := 0 to D - 1 do
  begin
    V := Src^[I] * K;
    if V < 0 then V := V - 0.5 else V := V + 0.5;
    Dst^[I] := Trunc(V);
  end;
  V := Big / 127.0;
  Store := V;
end;

{ attention for one layer at position P, float engine }
procedure AttendFloat(Lr, P: Integer);
var
  Hh, I, J, HOff: Integer;
  Off: Word;
  S, Big, Sum: Single;
begin
  for Hh := 0 to H - 1 do
  begin
    HOff := Hh * HD;
    Big := -1E30;
    for J := 0 to P do
    begin
      Off := Word(J * D + HOff);
      S := 0;
      for I := 0 to HD - 1 do
        S := S + BQ[HOff + I] * KC[Lr]^[Off + Word(I)];
      S := S * KS[Lr]^[J] / AttDiv;
      BS[J] := S;
      if S > Big then Big := S;
    end;
    Sum := 0;
    for J := 0 to P do
    begin
      BS[J] := SafeExp(BS[J] - Big);
      Sum := Sum + BS[J];
    end;
    for I := 0 to HD - 1 do
      BA[HOff + I] := 0;
    for J := 0 to P do
    begin
      if BS[J] = 0 then Continue;
      Off := Word(J * D + HOff);
      S := BS[J] * VS[Lr]^[J] / Sum;
      for I := 0 to HD - 1 do
        BA[HOff + I] := BA[HOff + I] + S * VC[Lr]^[Off + Word(I)];
    end;
  end;
end;

(* Feed letter number Tok at position P (0, 1, 2, ...).
   Fills Score[0..VOCAB-1]: how well each letter fits as the next one. *)
procedure StepFloat(Tok, P: Integer);
var
  I, Lr: Integer;
  EOff, POff: Word;
  S, ES, PS: Single;
begin
  EOff := Word(Tok * D);
  POff := Word(P * D);
  ES := Emb.Scale^[Tok];
  PS := PosT.Scale^[P];
  for I := 0 to D - 1 do
    BX[I] := Emb.W^[EOff + Word(I)] * ES + PosT.W^[POff + Word(I)] * PS;

  for Lr := 0 to L - 1 do
  begin
    { look back at the earlier letters }
    Norm(@BX, G1[Lr], @BH);
    MatVec(WK[Lr], @BH, @BT);
    KS[Lr]^[P] := Store(@KC[Lr]^[Word(P * D)], @BT);
    MatVec(WV[Lr], @BH, @BT);
    VS[Lr]^[P] := Store(@VC[Lr]^[Word(P * D)], @BT);
    MatVec(WQ[Lr], @BH, @BQ);
    AttendFloat(Lr, P);
    MatVec(WO[Lr], @BA, @BT);
    for I := 0 to D - 1 do
      BX[I] := BX[I] + BT[I];

    { think about it }
    Norm(@BX, G2[Lr], @BH);
    MatVec(F1[Lr], @BH, @BM);
    S := 0;
    for I := 0 to HID - 1 do
      if BM[I] < 0 then BM[I] := 0
      else S := S + BM[I];
    LayerAct[Lr] := S / HID;
    LayerLvl[Lr] := Trunc(LayerAct[Lr] * 256.0);
    MatVec(F2[Lr], @BM, @BT);
    for I := 0 to D - 1 do
      BX[I] := BX[I] + BT[I];
  end;
  Norm(@BX, GF, @BH);
  MatVec(Emb, @BH, @Score);
end;

{ ---- the integer engine ---------------------------------------------- }

(* Every value between the dot products is a 32-bit whole number counting
   65536ths.  What TINY.BIN gives as floating point is turned into whole
   numbers once, after loading, by taking the bits of each number apart:
   a row's scale becomes a 16-bit number M and a shift (scale = M / 2^Sh),
   a gain becomes a whole number of 4096ths.  The work buffers of the
   float engine are used as arrays of Longint, which have the same size. *)

function ISqrt(N: Longint): Longint;
var
  R, B, T: Longint;
begin
  R := 0;
  B := $40000000;
  while B > N do B := B shr 2;
  while B <> 0 do
  begin
    T := R + B;
    if N >= T then
    begin
      N := N - T;
      R := (R shr 1) + B;
    end
    else
      R := R shr 1;
    B := B shr 2;
  end;
  ISqrt := R;
end;

{ 1/Den as a 16-bit number M and a shift:  1/Den = M / 2^Sh }
procedure Recip(Den: Longint; var M: Word; var Sh: Integer);
var
  A: Integer;
begin
  A := 0;
  while Den > 65535 do begin Den := Den shr 1; Inc(A); end;
  while Den < 32768 do begin Den := Den shl 1; Dec(A); end;
  Den := $7FFFFFFF div Den;
  if Den > 65535 then Den := 65535;
  M := Word(Den);
  Sh := 31 + A;
end;

procedure FixScales(var T: TTable);
var
  R: Integer;
  B: Longint;
begin
  for R := 0 to T.Rows - 1 do
  begin
    B := PLongArr(T.Scale)^[R];
    with PScaleArr(T.Scale)^[R] do
      if B <= 0 then
      begin
        M := 0;
        Sh := 0;
      end
      else
      begin
        Sh := 142 - Integer((B shr 23) and 255);
        M := Word(((B and $7FFFFF) or $800000) shr 8);
      end;
  end;
end;

procedure FixGains(G: PSglArr);
var
  I, S: Integer;
  B, M: Longint;
begin
  for I := 0 to D - 1 do
  begin
    B := PLongArr(G)^[I];
    M := 0;
    if B and $7FFFFFFF <> 0 then
    begin
      M := (B and $7FFFFF) or $800000;
      S := 138 - Integer((B shr 23) and 255);
      if S >= 31 then M := 0
      else if S > 0 then M := (M + (Longint(1) shl (S - 1))) shr S
      else if S < 0 then M := M shl (-S);
      if B < 0 then M := -M;
    end;
    PLongArr(G)^[I] := M;
  end;
end;

procedure FixModel;
var
  I: Integer;
begin
  FixScales(Emb);
  FixScales(PosT);
  for I := 0 to L - 1 do
  begin
    FixGains(G1[I]);
    FixGains(G2[I]);
    FixScales(WQ[I]);
    FixScales(WK[I]);
    FixScales(WV[I]);
    FixScales(WO[I]);
    FixScales(F1[I]);
    FixScales(F2[I]);
    VMax[I] := 1;
  end;
  FixGains(GF);
  SqrtD := ISqrt(Longint(D) shl 24);                   { sqrt(D) in 4096ths }
  Recip(127 * ISqrt(Longint(HD) shl 24), AttM, AttSh); { 1 / (127 sqrt(HD)) }
end;

(* X[0..N-1] as 16-bit numbers:  X[i] is about Q[i] * 2^S.  The largest
   takes 15 bits.  Returns S. *)
function QuantFix(X: PLongArr; N: Integer; Q: PI16Arr): Integer;
var
  I, S: Integer;
  M, V, Half: Longint;
begin
  M := 0;
  for I := 0 to N - 1 do
  begin
    V := Abs(X^[I]);
    if V > M then M := V;
  end;
  S := 0;
  if M = 0 then
  begin
    for I := 0 to N - 1 do Q^[I] := 0;
    QuantFix := 0;
    Exit;
  end;
  while (M shr S) > 32766 do Inc(S);
  if S > 0 then
  begin
    Half := Longint(1) shl (S - 1);
    for I := 0 to N - 1 do
    begin
      V := X^[I];
      if V < 0 then Q^[I] := -((Half - V) shr S)
      else Q^[I] := (V + Half) shr S;
    end;
  end
  else
  begin
    while (M shl 1) <= 32766 do
    begin
      M := M shl 1;
      Dec(S);
    end;
    for I := 0 to N - 1 do
      if X^[I] < 0 then Q^[I] := -((-X^[I]) shl (-S))
      else Q^[I] := X^[I] shl (-S);
  end;
  QuantFix := S;
end;

{ Y = table * (Q * 2^S) }
procedure MatFix(const T: TTable; Q: PI16Arr; S: Integer; Y: PLongArr);
var
  R, Cols: Integer;
begin
  Cols := T.Cols;
  for R := 0 to T.Rows - 1 do
    with PScaleArr(T.Scale)^[R] do
      Y^[R] := MulShr(DotS8I16(@T.W^[Word(Longint(R) * Cols)], Q, Cols), M, Sh - S);
end;

(* Y = X divided by its root mean square, times the gains G.  The square
   root is taken of 12-bit numbers, whose squares add up within 32 bits;
   the division is by a 16-bit reciprocal. *)
procedure NormFix(X: PLongArr; G: PSglArr; Y: PLongArr);
var
  I, S, E: Integer;
  Acc, F, V: Longint;
begin
  S := QuantFix(X, D, @XQ);
  Acc := 0;
  for I := 0 to D - 1 do
  begin
    V := XQ[I] div 8;
    Acc := Acc + V * V;
  end;
  if Acc = 0 then
  begin
    for I := 0 to D - 1 do Y^[I] := 0;
    Exit;
  end;
  F := (SqrtD shl 15) div ISqrt(Acc);
  E := 0;
  while F > 65535 do
  begin
    F := F shr 1;
    Inc(E);
  end;
  for I := 0 to D - 1 do
    Y^[I] := MulShr(Longint(XQ[I]) * PLongArr(G)^[I], Word(F), 26 - E);
end;

{ keep a list of D numbers as bytes, the largest as 127; returns the largest }
function StoreFix(Dst: PS8Arr; Src: PLongArr): Longint;
var
  I, Sh: Integer;
  Big, V, Den: Longint;
begin
  Big := 0;
  for I := 0 to D - 1 do
  begin
    V := Abs(Src^[I]);
    if V > Big then Big := V;
  end;
  if Big = 0 then Big := 1;
  Sh := 0;
  while (Big shr Sh) > $7FFFFF do Inc(Sh);
  Den := Big shr Sh;
  for I := 0 to D - 1 do
  begin
    V := ((Abs(Src^[I]) shr Sh) * 127 + Den shr 1) div Den;
    if Src^[I] < 0 then Dst^[I] := -V else Dst^[I] := V;
  end;
  StoreFix := Big;
end;

{ exp(-Diff / 2^Shift / 128) * 32767, for Diff of 0 or more }
function ExpOf(Diff: Longint; Shift: Integer): Longint;
begin
  Diff := (Diff + (Longint(1) shl (Shift - 1))) shr Shift;
  if Diff > 1535 then ExpOf := 0 else ExpOf := ExpTab[Integer(Diff)];
end;

procedure StepFix(Tok, P: Integer);
var
  I, J, Lr, Hh, HOff, S, Sq, Sw, Vsh, Rs: Integer;
  Big, Acc, ESum, V, Wm: Longint;
  Rm: Word;
  FX, FH, FT, FQ, FA, FM: PLongArr;
begin
  FX := @BX; FH := @BH; FT := @BT; FQ := @BQ; FA := @BA; FM := @BM;
  (* a new text: forget the value scales of the last one, so that an
     answer does not depend on what was asked before *)
  if P = 0 then
    for Lr := 0 to L - 1 do VMax[Lr] := 1;
  for I := 0 to D - 1 do
  begin
    with PScaleArr(Emb.Scale)^[Tok] do
      V := MulShr(Emb.W^[Word(Tok * D + I)], M, Sh - 16);
    with PScaleArr(PosT.Scale)^[P] do
      FX^[I] := V + MulShr(PosT.W^[Word(P * D + I)], M, Sh - 16);
  end;

  for Lr := 0 to L - 1 do
  begin
    { look back at the earlier letters }
    NormFix(FX, G1[Lr], FH);
    S := QuantFix(FH, D, @XQ);
    { the key of this place: its bytes, and its scale over 127 sqrt(HD) }
    MatFix(WK[Lr], @XQ, S, FT);
    Big := StoreFix(@KC[Lr]^[Word(P * D)], FT);
    Sw := 0;
    while Big > 65535 do
    begin
      Big := Big shr 1;
      Inc(Sw);
    end;
    with PScaleArr(KS[Lr])^[P] do
    begin
      M := Word(MulShr(Big, AttM, 16));
      Sh := AttSh + 4 - Sw - 16;
    end;
    MatFix(WV[Lr], @XQ, S, FT);
    Big := StoreFix(@VC[Lr]^[Word(P * D)], FT);
    PLongArr(VS[Lr])^[P] := Big;
    if Big > VMax[Lr] then VMax[Lr] := Big;
    MatFix(WQ[Lr], @XQ, S, FQ);
    Sq := QuantFix(FQ, D, @QQ);
    Vsh := 0;
    while (VMax[Lr] shr Vsh) > 32767 do Inc(Vsh);
    for Hh := 0 to H - 1 do
    begin
      HOff := Hh * HD;
      Big := -MaxLongint;
      { how well each earlier place answers this one, in 1024ths }
      for J := 0 to P do
      begin
        with PScaleArr(KS[Lr])^[J] do
          V := MulShr(DotS8I16(@KC[Lr]^[Word(J * D + HOff)], @QQ[HOff], HD), M, Sh + 6 - Sq);
        EE[J] := V;
        if V > Big then Big := V;
      end;
      ESum := 0;
      Wm := 0;
      for J := 0 to P do
      begin
        V := ExpOf(Big - EE[J], 3);
        ESum := ESum + V;
        V := V * (PLongArr(VS[Lr])^[J] shr Vsh);
        EE[J] := V;
        if V > Wm then Wm := V;
      end;
      Sw := 0;
      while (Wm shr Sw) > 32767 do Inc(Sw);
      for J := 0 to P do WW[J] := EE[J] shr Sw;
      Recip(127 * ESum, Rm, Rs);
      for I := 0 to HD - 1 do
        FA^[HOff + I] := MulShr(DotStride(@VC[Lr]^[Word(HOff + I)], D, @WW, P + 1), Rm, Rs - Sw - Vsh);
    end;
    S := QuantFix(FA, D, @XQ);
    MatFix(WO[Lr], @XQ, S, FT);
    for I := 0 to D - 1 do
      FX^[I] := FX^[I] + FT^[I];

    { think about it }
    NormFix(FX, G2[Lr], FH);
    S := QuantFix(FH, D, @XQ);
    MatFix(F1[Lr], @XQ, S, FM);
    Acc := 0;
    for I := 0 to HID - 1 do
      if FM^[I] < 0 then FM^[I] := 0
      else Acc := Acc + FM^[I] shr 8;
    LayerLvl[Lr] := Acc div HID;
    {$IFDEF TINYMODERN}LayerAct[Lr] := LayerLvl[Lr] / 256.0;{$ENDIF}
    S := QuantFix(FM, HID, @XQ);
    MatFix(F2[Lr], @XQ, S, FT);
    for I := 0 to D - 1 do
      FX^[I] := FX^[I] + FT^[I];
  end;
  NormFix(FX, GF, FH);
  S := QuantFix(FH, D, @XQ);
  MatFix(Emb, @XQ, S, PLongArr(@Score));     { Score holds Longints here }
end;

(* Feed letter number Tok at position P (0, 1, 2, ...).
   Fills Score[0..VOCAB-1]: how well each letter fits as the next one. *)
procedure Step(Tok, P: Integer);
begin
  if Fixed then StepFix(Tok, P) else StepFloat(Tok, P);
end;

function ChosenFix(Tok: Integer): Integer;
var
  I, Best: Integer;
  Sum: Longint;
  FS: PLongArr;
begin
  FS := @Score;
  Best := 0;
  for I := 1 to VOCAB - 1 do
    if FS^[I] > FS^[Best] then Best := I;
  Sum := 0;
  for I := 0 to VOCAB - 1 do
    Sum := Sum + ExpOf(FS^[Best] - FS^[I], 9);
  LastMil := Integer((1000 * ExpOf(FS^[Best] - FS^[Tok], 9)) div Sum);
  {$IFDEF TINYMODERN}LastConf := LastMil / 1000.0;{$ENDIF}
  ChosenFix := Tok;
end;

function PickFix: Integer;
var
  I, Best, Selected: Integer;
  Sum, Cum, R: Longint;
  FS: PLongArr;
begin
  FS := @Score;
  Best := 0;
  for I := 1 to VOCAB - 1 do
    if FS^[I] > FS^[Best] then Best := I;
  Selected := Best;
  if Creativity > 0 then
  begin
    (* a letter's chance: exp of how far it is behind the best, over
       Creativity/5; letters under 0.15 are left out *)
    Sum := 0;
    for I := 0 to VOCAB - 1 do
    begin
      EE[I] := ExpOf((FS^[Best] - FS^[I]) * 5 div Creativity, 9);
      if EE[I] < 4916 then EE[I] := 0;
      Sum := Sum + EE[I];
    end;
    R := MulShr(Sum, Random(10000), 4);
    Cum := 0;
    I := 0;
    while I < VOCAB do
    begin
      Cum := Cum + EE[I];
      if (EE[I] > 0) and (R < MulShr(Cum, 10000, 4)) then
      begin
        Selected := I;
        I := VOCAB;
      end
      else
        Inc(I);
    end;
  end;
  PickFix := ChosenFix(Selected);
end;

{ ---- choosing letters ------------------------------------------------- }

function Chosen(Tok: Integer): Integer;
var
  I: Integer;
  Sum: Single;
begin
  Sum := 0;
  for I := 0 to VOCAB - 1 do
    Sum := Sum + SafeExp(Score[I] - Score[Tok]);
  LastConf := 1.0 / Sum;
  LastMil := Trunc(LastConf * 1000.0);
  Chosen := Tok;
end;

(* Pick the next letter. With creativity 0 it is always the best one.
   Otherwise choose at random among the letters that fit nearly as well. *)
function Pick: Integer;
var
  I, Best: Integer;
  T, Sum, R: Single;
begin
  if Fixed then
  begin
    Pick := PickFix;
    Exit;
  end;
  Best := 0;
  for I := 1 to VOCAB - 1 do
    if Score[I] > Score[Best] then Best := I;
  if Creativity <= 0 then
  begin
    Pick := Chosen(Best);
    Exit;
  end;
  T := Creativity / 5.0;
  Sum := 0;
  for I := 0 to VOCAB - 1 do
  begin
    BS[I] := SafeExp((Score[I] - Score[Best]) / T);
    if BS[I] < 0.15 then BS[I] := 0;
    Sum := Sum + BS[I];
  end;
  R := Sum * Random(10000) / 10000.0;
  for I := 0 to VOCAB - 1 do
  begin
    R := R - BS[I];
    if (R < 0) and (BS[I] > 0) then
    begin
      Pick := Chosen(I);
      Exit;
    end;
  end;
  Pick := Chosen(Best);
end;

function NowMs: Longint;
begin
  if Assigned(ClockMs) then NowMs := ClockMs else NowMs := 0;
end;

(* Answer question Q into Answer. The callbacks (may be nil) hear about
   progress through the question and about every new letter.
   Returns the number of letters; Tenths gets the time taken. *)
function Think(const Q: String; var Answer: String; var Tenths: Longint;
  OnStep: TStepProc; OnLetter: TLetterProc): Integer;
var
  P, N, Tok: Integer;
  T0: Longint;
begin
  T0 := NowMs;
  Answer := '';
  N := Length(Q);
  AbortThink := False;
  P := 0;
  while P < N do
  begin
    if Assigned(OnStep) then OnStep(P, N);
    if Assigned(OnIdle) then OnIdle;
    if AbortThink then Break;
    Step(Ord(Q[P + 1]) - 30, P);
    Inc(P);
  end;
  if not AbortThink then
  begin
    Step(1, P);                              { end of the question }
    Inc(P);
    while P < CTX do
    begin
      Tok := Pick;
      if Tok <= 1 then Break;                { end of the answer }
      Answer := Answer + Chr(Tok + 30);
      if Assigned(OnLetter) then OnLetter(Tok + 30);
      if Assigned(OnIdle) then OnIdle;
      if AbortThink then Break;
      Step(Tok, P);
      Inc(P);
    end;
  end;
  Tenths := (NowMs - T0) div 100;
  Think := Length(Answer);
end;

(* Clean up a typed line: printable letters only, no trailing spaces,
   and CAPS LOCK text turned into lower case. *)
function Clean(const Line: String; var Q: String): Integer;
var
  I, Lower, Upper: Integer;
begin
  Q := '';
  Lower := 0;
  Upper := 0;
  I := 1;
  while (I <= Length(Line)) and (Length(Q) < MAXQ) do
  begin
    if (Line[I] >= ' ') and (Line[I] <= '~') then
      Q := Q + Line[I];
    Inc(I);
  end;
  while (Length(Q) > 0) and (Q[Length(Q)] = ' ') do
    Delete(Q, Length(Q), 1);
  for I := 1 to Length(Q) do
  begin
    if (Q[I] >= 'a') and (Q[I] <= 'z') then Inc(Lower);
    if (Q[I] >= 'A') and (Q[I] <= 'Z') then Inc(Upper);
  end;
  if (Upper > 0) and (Lower = 0) then
    for I := 1 to Length(Q) do
      if (Q[I] >= 'A') and (Q[I] <= 'Z') then
        Q[I] := Chr(Ord(Q[I]) + 32);
  Clean := Length(Q);
end;

{ is Q the word W (W in lower case), ignoring case? }
function IsWord(const Q, W: String): Boolean;
var
  I: Integer;
begin
  IsWord := False;
  if Length(Q) <> Length(W) then Exit;
  for I := 1 to Length(Q) do
    if (Ord(Q[I]) or 32) <> Ord(W[I]) then Exit;
  IsWord := True;
end;

function NumStr(N: Longint): String;
var
  S: String[12];
begin
  Str(N, S);
  NumStr := S;
end;

function TenthsStr(T: Longint): String;
begin
  TenthsStr := NumStr(T div 10) + '.' + NumStr(T mod 10);
end;

{ ---- plain text: questions from a file, answers to a file --------------- }

procedure PlainRun(var Fin, Fout: Text);
var
  Line, Q, Answer: String;
  Letters: Integer;
  Tenths: Longint;
begin
  WriteLn(Fout, 'TINY 2 - a neural network that answers questions.');
  WriteLn(Fout, 'Loading TINY.BIN ...');
  WriteLn(Fout, 'Ready: ', L, ' layers, ', D, ' wide. Creativity ', Creativity,
    ' (TINY 0 to TINY 9).');
  WriteLn(Fout, 'Ask about countries, animals, space, the body, nature, science, food,');
  WriteLn(Fout, 'sums, numbers, spelling, words, shapes, history, music or computers.');
  WriteLn(Fout, 'Type QUIT to stop.');
  while True do
  begin
    WriteLn(Fout);
    Write(Fout, '> ');
    if Eof(Fin) then Break;
    ReadLn(Fin, Line);
    if Clean(Line, Q) = 0 then Continue;
    if IsWord(Q, 'quit') or IsWord(Q, 'exit') then Break;
    Letters := Think(Q, Answer, Tenths, nil, nil);
    WriteLn(Fout, '  ', Answer);
    {$IFDEF TINYMODERN}if Assigned(OnAnswer) then begin Flush(Fout); OnAnswer(Answer) end;{$ENDIF}
    WriteLn(Fout, '   [', Letters, ' letters in ', TenthsStr(Tenths), ' seconds]');
  end;
  WriteLn(Fout, 'Goodbye!');
end;

{ ---- /BENCH ------------------------------------------------------------- }

procedure RunBench(var Fout: Text; const Build: String; Fpu: Integer);
var
  I, Letters, Old: Integer;
  Answer, Question: String;
  Tenths, T0, T1, Ms, Tokens, AllMs, AllTokens: Longint;
begin
  Old := Creativity;
  Creativity := 0;
  AllMs := 0;
  AllTokens := 0;
  WriteLn(Fout, 'TINY 2.1 benchmark');
  Write(Fout, 'build: ', Build, '   engine: ');
  if UseInt then Write(Fout, 'INTEGER') else Write(Fout, 'FLOAT');
  {$IFDEF TINYASM}
  Write(Fout, ' + ASM');
  {$ELSE}
  Write(Fout, ' (Pascal)');
  {$ENDIF}
  Write(Fout, '   coprocessor: ');
  if Fpu > 0 then WriteLn(Fout, 'yes')
  else if Fpu = 0 then WriteLn(Fout, 'no (emulated)')
  else WriteLn(Fout, 'unknown');
  WriteLn(Fout);
  for I := 1 to NBENCH do
  begin
    T0 := NowMs;
    Question := BenchQ[I];
    Letters := Think(Question, Answer, Tenths, nil, nil);
    T1 := NowMs;
    if AbortThink then Break;
    Ms := T1 - T0;
    Tokens := Length(BenchQ[I]) + 1 + Letters;
    AllMs := AllMs + Ms;
    AllTokens := AllTokens + Tokens;
    WriteLn(Fout, BenchQ[I]);
    WriteLn(Fout, '  ', Answer);
    {$IFDEF TINYMODERN}
    WriteLn(Fout, '  ', Tokens, ' tokens in ', Ms, ' ms');
    {$ELSE}
    WriteLn(Fout, '  ', Tokens, ' letters in ', TenthsStr(Ms div 100), ' s');
    {$ENDIF}
  end;
  WriteLn(Fout);
  {$IFDEF TINYMODERN}
  WriteLn(Fout, 'total: ', AllTokens, ' tokens in ', AllMs, ' ms');
  if AllMs > 0 then
    WriteLn(Fout, 'speed: ', (AllTokens * 1000.0 / AllMs):0:1,
      ' tokens/s   average answer: ', (AllMs / NBENCH):0:1, ' ms');
  {$ELSE}
  WriteLn(Fout, 'total: ', AllTokens, ' letters in ', TenthsStr(AllMs div 100), ' s');
  if AllMs > 0 then
    WriteLn(Fout, 'speed: ', TenthsStr(AllTokens * 10000 div AllMs),
      ' letters/s   average answer: ', TenthsStr(AllMs div (NBENCH * 100)), ' s');
  {$ENDIF}
  Creativity := Old;
end;

begin
  Creativity := 5;
  UseInt := True;
  OnFail := nil;
  OnLoad := nil;
  ClockMs := nil;
  OnIdle := nil;
end.
