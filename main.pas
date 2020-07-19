unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Themes, WinApi.CommCtrl,
  ShellAPI, Vcl.ExtCtrls,
  K.Update, K.Console, K.Strings, Vcl.Imaging.pngimage;

type
  TFrmWebMConverter = class(TForm)
    ListView1: TListView;
    BtnConvert: TButton;
    BtnAddFile: TButton;
    OpenDialog1: TOpenDialog;
    CheckBox1: TCheckBox;
    PanelHeader: TPanel;
    LabelTitle: TLabel;
    PanelHeaderLogo: TPanel;
    ImgLogo: TImage;
    procedure ListView1CustomDrawSubItem(Sender: TCustomListView;
      Item: TListItem; SubItem: Integer; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure BtnConvertClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure BtnAddFileClick(Sender: TObject);
  private
    ListViewWndProc_Org: TWndMethod;

    procedure ListViewWndProc(var Msg: TMessage);
    procedure AddFile(FileName: string);
  public
  end;

type
  TListItemHelper = class helper for TListItem
  public
    function SubItemRect(SubItemIndex: Integer; Code: TDisplayCode): TRect;
  end;

type
  TFileInfo = class
    FileName: string;
    FileSize: Cardinal;
  end;
var
  FrmWebMConverter: TFrmWebMConverter;

implementation

{$R *.dfm}

{ Common }
function StrTimeToCardinal(Str: string): Cardinal;
begin
  Result := StrToIntDef(Copy(Str, 1, 2), 0)*3600 +
            StrToIntDef(Copy(Str, 4, 2), 0)*60 +
            StrToIntDef(Copy(Str, 7, 2), 0);
end;

{ Helper }

function TListItemHelper.SubItemRect(SubItemIndex: Integer; Code: TDisplayCode): TRect;
const
  Codes: array[TDisplayCode] of Longint = (LVIR_BOUNDS, LVIR_ICON, LVIR_LABEL,
    LVIR_SELECTBOUNDS);
begin
  ListView_GetSubItemRect(ListView.Handle, Index, SubItemIndex, Codes[Code], @Result);
end;

{ TFrmWebConverter }

procedure TFrmWebMConverter.ListView1CustomDrawSubItem(Sender: TCustomListView;
  Item: TListItem; SubItem: Integer; State: TCustomDrawState;
  var DefaultDraw: Boolean);
var
  Element: TThemedElementDetails;
  R: TRect;
  DC: HDC;
  Progress: 1..100;
begin
  if ((Sender as TListView).ViewStyle = vsReport) and (SubItem = 1) then
  begin
    Progress := StrToInt(Item.SubItems[0]);

    DC := GetDC(Sender.Handle);

    R := Item.SubItemRect(SubItem, drBounds);

    InflateRect(R, -1, -1);
    Element := StyleServices.GetElementDetails(tpBar);
    StyleServices.DrawElement(DC, Element, R, nil);

    R.Right := R.Left + MulDiv(Progress, R.Right - R.Left, 100);
    Element := StyleServices.GetElementDetails(tpChunk);
    StyleServices.DrawElement(DC, Element, R);

    ReleaseDC(Sender.Handle, DC);
    DefaultDraw := False;
  end;
end;

procedure TFrmWebMConverter.AddFile(FileName: string);
var
  Item: TListItem;
  Info: TFileInfo;
  Ext: string;
  Loop: Integer;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  if (Ext <> '.mp4') and (Ext <> '.avi') and (Ext <> '.asf') and (Ext <> '.mkv') and (Ext <> '.mpeg') and (Ext <> '.wmv') then Exit;

  for Loop := 0 to ListView1.Items.Count-1 do
  begin
    Item := ListView1.Items.Item[Loop];
    if TFileInfo(Item.Data).FileName = FileName then Exit;
  end;

  Info := TFileInfo.Create;
  Info.FileName := FileName;
  Info.FileSize := 0;

  Item := ListView1.Items.Add;
  Item.Caption := ExtractFileName(Info.FileName);
  Item.SubItems.Add('0');
  Item.SubItems.Add('wait');
  Item.Data := Info;
end;

procedure TFrmWebMConverter.BtnAddFileClick(Sender: TObject);
var
  FileName: string;
begin
  if OpenDialog1.Execute then
    for FileName in OpenDialog1.Files do
      AddFile(FileName);
end;

procedure TFrmWebMConverter.BtnConvertClick(Sender: TObject);
var
  CMD: TConsole;
  Item: TListItem;
  FFMpeg, Param, SrcFile, DstFile, Temp: string;
  Max, Val: Cardinal;
  Loop: Integer;
begin
  FFMpeg := ExtractFilePath(ParamStr(0))+'ffmpeg.exe';
  if not FileExists(FFMpeg) then
  begin
    Showmessage('FFmpeg not found.');
    Exit;
  end;

  BtnAddFile.Enabled := False;
  BtnConvert.Enabled := False;

  for Loop := 0 to ListView1.Items.Count-1 do
  begin
    Item := ListView1.Items.Item[Loop];
    if Item.SubItems[1] <> 'wait' then Continue;

    SrcFile := TFileInfo(Item.Data).FileName;
    DstFile := ChangeFileExt(SrcFile, '.webm');
    if FileExists(DstFile) then DeleteFile(DstFile);

    Item.SubItems[1] := 'working';

    if CheckBox1.Checked then
      Param := ' -i "'+SrcFile+'" -c:v libvpx-vp9 -deadline realtime -speed 4 "'+DstFile+'"'
    else
      Param := ' -i "'+SrcFile+'" -c:v libvpx-vp9 -crf 30 -b:v 0 "'+DstFile+'"';

    CMD := TConsole.Create;
    CMD.CommandLine := FFMpeg+Param;
    CMD.Execute(procedure(ANewLine: string)
    begin
      Temp := Parsing(ANewLine, 'Duration: ', ', ');
      if Temp <> '' then Max := StrTimeToCardinal(Temp);

      Temp := Parsing(ANewLine, 'time=', ' ');
      if Temp <> '' then Val := StrTimeToCardinal(Temp);

      if (Val > 0) and (Max > 0) then Item.SubItems[0] := IntToStr(Round(Val*100/Max));
    end);
    while CMD.IsRunning do Application.ProcessMessages;

    CMD.Free;

    Item.SubItems[1] := 'completed';
    Item.SubItems[0] := '100';
  end;

  BtnAddFile.Enabled := True;
  BtnConvert.Enabled := True;
end;

procedure TFrmWebMConverter.ListViewWndProc(var Msg: TMessage);
  procedure DropFiles(var msg: TMessage);
  const
    MAXFILENAME = 511;
  var
    Loop, Count: integer;
    DropFileName : array [0..MAXFILENAME] of Char;
  begin
    Count := DragQueryFile(msg.WParam, $FFFFFFFF, dropFileName, MAXFILENAME);
    for Loop := 0 to Count-1 do
    begin
      DragQueryFile(Msg.WParam, Loop, DropFileName, MAXFILENAME);
      AddFile(DropFileName);
    end;
    DragFinish(msg.WParam);
  end;
begin
  case Msg.Msg of
    WM_DROPFILES: DropFiles(Msg);
  else
    if Assigned(ListViewWndProc_Org) then ListViewWndProc_Org(Msg);
  end;
end;

procedure TFrmWebMConverter.FormClose(Sender: TObject;
  var Action: TCloseAction);
var
  Loop: Integer;
begin
  DragAcceptFiles(ListView1.Handle, False);

  for Loop := ListView1.Items.Count-1 downto 0 do
    Dispose(ListView1.Items.Item[Loop].Data);
end;

procedure TFrmWebMConverter.FormCreate(Sender: TObject);
begin
  Application.Title := Caption;

  CheckUpdate('http://down.kilho.net/update.php', 'WebMConvert');

  ListViewWndProc_Org := ListView1.WindowProc;
  ListView1.WindowProc := ListViewWndProc;

  DragAcceptFiles(ListView1.Handle, True);

  //AddFile('z:\win32\release\test.mp4');
end;

end.
