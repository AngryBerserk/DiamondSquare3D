unit Unit2;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, Math, FMX.EditBox, FMX.SpinBox,
  FMX.Edit, FMX.Objects, System.Math.Vectors, FMX.Types3D, FMX.Controls3D,
  FMX.MaterialSources, FMX.Objects3D, FMX.Viewport3D, FMX.Ani;


const
  _mapSize = 5;
  mapSize = 256;
  {
  waterLevel=40;
  snowLevel=200;
  }

type
  TMapArr = Array[0..mapSize+1,0..mapSize+1] of Single;
  TGraphMap = Array[0..mapSize+1,0..mapSize+1] of TProxyObject;
  TForm2 = class(TForm)
    Button1: TButton;
    Panel1: TPanel;
    ESeed: TEdit;
    TWater: TTrackBar;
    TSnow: TTrackBar;
    SWater: TSpinBox;
    Panel2: TPanel;
    SSnow: TSpinBox;
    ERoughness: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    E1P: TEdit;
    E2P: TEdit;
    E4P: TEdit;
    E3P: TEdit;
    EEdge: TEdit;
    Label3: TLabel;
    ChSqr: TCheckBox;
    ChNormalize: TCheckBox;
    Camera1: TCamera;
    Light1: TLight;
    View: TViewport3D;
    LightMaterialSource1: TLightMaterialSource;
    Mesh1: TMesh;
    Dummy1: TDummy;
    Dummy2: TDummy;
    FloatAnimation1: TFloatAnimation;
    Cube1: TCube;
    LightMaterialSource2: TLightMaterialSource;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure TWaterChange(Sender: TObject);
    procedure SWaterChange(Sender: TObject);
    procedure TSnowChange(Sender: TObject);
    procedure SSnowChange(Sender: TObject);
    procedure ChSqrChange(Sender: TObject);
    procedure Panel2Paint(Sender: TObject; Canvas: TCanvas;
      const ARect: TRectF);
    procedure Mesh1MouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; var Handled: Boolean);
    procedure FormShow(Sender: TObject);
  private
    Depth:Word;
    Map:TMapArr;
    Plane:TGraphMap;
    Normalized:TMapArr;
    finish:Boolean;
    mapMin,
    mapMax:Single;
    procedure Draw;
    function getMapColor(const c:Byte):TAlphaColor;
    function compress(const c:Single):Byte;
    procedure Square;
    procedure Diamond;
    procedure InitMap;
    procedure Normalize;
    procedure DumpMapToFile(const FileName:String);
    function setAverage(const v1,v2,v3,v4:Single):Single;
    function getMapVal(const x,y:Integer):Single;
    function getPoint(const pointNum:Byte;const x,y:Word):TPoint;
    procedure CreateMesh;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form2: TForm2;

implementation

{$R *.fmx}
function f(x,z : Double) : Double;
var
  temp : Double;
begin
  temp := x*x+z*z;
  if temp < Epsilon then
    temp := Epsilon;

  Result := -2000*Sin(temp/180*Pi)/temp;
end;

procedure TForm2.CreateMesh;
var
  u, v : Double;
  P : array [0..3] of TPoint3D;
  d : Integer;
  NP, NI : Integer;
  k : Integer;
begin
  Mesh1.Data.Clear;
  d := 1;

  NP := 0;
  NI := 0;

  Mesh1.Data.VertexBuffer.Length := Round(4*sqr(mapSize))*4;
  Mesh1.Data.IndexBuffer.Length := Round(4*sqr(mapSize))*6;
  u := 0;
  while u < mapSize do begin
    v := 0;
    while v < mapSize do begin
      // Set up the points in the XZ plane
      P[0].x := u;
      P[0].z := v;
      P[1].x := u+d;
      P[1].z := v;
      P[2].x := u+d;
      P[2].z := v+d;
      P[3].x := u;
      P[3].z := v+d;

      // Calculate the corresponding function values for Y = f(X,Z)

      P[0].y := u;
      P[1].y := u;
      P[2].y := v;
      P[3].y := v;


      P[0].y := Normalized[Round(P[0].x),Round(P[0].z)];
      P[1].y := Normalized[Round(P[1].x),Round(P[1].z)];
      P[2].y := Normalized[Round(P[2].x),Round(P[2].z)];
      P[3].y := Normalized[Round(P[3].x),Round(P[3].z)];

      with Mesh1.Data do begin
        // Set the points
        with VertexBuffer do begin
          Vertices[NP+0] := P[0];
          Vertices[NP+1] := P[1];
          Vertices[NP+2] := P[2];
          Vertices[NP+3] := P[3];
        end;

        // Map the colors
        with VertexBuffer do begin
          TexCoord0[NP+0] := PointF(0,(P[0].y+35)/45);
          TexCoord0[NP+1] := PointF(0,(P[1].y+35)/45);
          TexCoord0[NP+2] := PointF(0,(P[2].y+35)/45);
          TexCoord0[NP+3] := PointF(0,(P[3].y+35)/45);
        end;

        // Map the triangles
        IndexBuffer[NI+0] := NP+1;
        IndexBuffer[NI+1] := NP+2;
        IndexBuffer[NI+2] := NP+3;
        IndexBuffer[NI+3] := NP+3;
        IndexBuffer[NI+4] := NP+0;
        IndexBuffer[NI+5] := NP+1;
      end;

      NP := NP+4;
      NI := NI+6;

      v := v+d;
    end;
    u := u+d;
  end;
  Mesh1.TwoSide:=true;
  Mesh1.Data.CalcFaceNormals(true);
end;

function TForm2.getMapVal(const x: Integer; const y: Integer):Single;
  var xx,yy:Word;
begin
   {
  if x<0 then xx:=mapSize-x
    else
      if x>mapSize then xx:=x-mapSize
        else xx:=x;
  if y<0 then yy:=mapSize-y
    else
      if y>mapSize then yy:=y-mapSize
        else yy:=y;
  result:=map[xx,yy];
    }

  if (x>=0) and (y>=0) and (x<=mapSize) and (y<=mapSize) then
    result:=map[x,y]
      else
        result:=StrToInt(EEdge.text);

end;

function TForm2.setAverage(const v1: Single; const v2: Single; const v3: Single; const v4: Single):Single;
  var dx:Word;Rand:Single;Rx:Single;
begin
  Rx:=StrToFloat(ERoughness.Text);
  dx:=Round(mapSize/(IntPower(2,Depth)));
  Rand:=Random*2*Rx*Dx-Rx*Dx;
  result:=(v1+v2+v3+v4)/4+Rand;

  //result:=(v1+v2+v3+v4)/4
end;

procedure TForm2.Square;
  var x,y:Word;
      loopValue:Word;
      p1,p2,p3,p4,p5:TPoint;
begin
  LoopValue:=Round(IntPower(2,Depth))-1;
  for y := 0 to LoopValue do
    for x := 0 to LoopValue do
      Begin
        p1:=getPoint(1,x,y);
        p2:=getPoint(2,x,y);
        p3:=getPoint(3,x,y);
        p4:=getPoint(4,x,y);
        p5:=getPoint(5,x,y);
        map[p5.x,p5.y]:=setAverage(getMapVal(p1.x,p1.y),getMapVal(p2.x,p2.y),getMapVal(p3.x,p3.y),getMapVal(p4.x,p4.y));
      End;
end;

procedure TForm2.SSnowChange(Sender: TObject);
begin
  TSnow.Value:=SSnow.Value;
  Draw
end;

procedure TForm2.SWaterChange(Sender: TObject);
begin
  TWater.Value:=SWater.Value;
  Draw
end;

procedure TForm2.TSnowChange(Sender: TObject);
begin
  SSnow.Value:=TSnow.Value;
  Draw
end;

procedure TForm2.TWaterChange(Sender: TObject);
begin
  SWater.Value:=TWater.Value;
  Draw
end;

procedure TForm2.Diamond;
  var x,y:Word;
      p1,p2,p3,p4,p5:TPoint;
      LoopValue:Word;
begin
  LoopValue:=Round(IntPower(2,Depth));
  for y := 0 to LoopValue do
    for x := 0 to LoopValue do
      Begin
        //get upper point
        p1:=getPoint(1,x,y);
        p2:=getPoint(2,x,y);
        p3:=getPoint(5,x,y);
        p4:=getPoint(6,x,y);
        p5:=getPoint(7,x,y);
        map[p5.x,p5.y]:=setAverage(getMapVal(p1.x,p1.y),getMapVal(p2.x,p2.y),getMapVal(p3.x,p3.y),getMapVal(p4.x,p4.y));
        //get left point
        p1:=getPoint(1,x,y);
        p2:=getPoint(3,x,y);
        p3:=getPoint(5,x,y);
        p4:=getPoint(9,x,y);
        p5:=getPoint(8,x,y);
        map[p5.x,p5.y]:=setAverage(getMapVal(p1.x,p1.y),getMapVal(p2.x,p2.y),getMapVal(p3.x,p3.y),getMapVal(p4.x,p4.y));
        //get right point
        p1:=getPoint(2,x,y);
        p2:=getPoint(4,x,y);
        p3:=getPoint(5,x,y);
        p4:=getPoint(12,x,y);
        p5:=getPoint(13,x,y);
        map[p5.x,p5.y]:=setAverage(getMapVal(p1.x,p1.y),getMapVal(p2.x,p2.y),getMapVal(p3.x,p3.y),getMapVal(p4.x,p4.y));
        //get down point
        p1:=getPoint(3,x,y);
        p2:=getPoint(4,x,y);
        p3:=getPoint(5,x,y);
        p4:=getPoint(10,x,y);
        p5:=getPoint(11,x,y);
        map[p5.x,p5.y]:=setAverage(getMapVal(p1.x,p1.y),getMapVal(p2.x,p2.y),getMapVal(p3.x,p3.y),getMapVal(p4.x,p4.y));
      End;
  Depth:=Depth+1;
end;

function TForm2.getPoint(const pointNum: Byte;const x,y:Word):TPoint;
  var dx,dy:Word;
      x1,x2,y1,y2,xMid,yMid:Word;
begin
  dx:=Round(mapSize/(IntPower(2,Depth)));
  dy:=Round(mapSize/(IntPower(2,Depth)));
  if dx = 1 then finish:=true;
  x1:=x*dx;
  y1:=y*dy;
  x2:=x1+dx;
  y2:=y1+dy;
  xMid:=((x1+x2) div 2);
  yMid:=((y1+y2) div 2);

  xMid:=((x2-x1) div 2);
  yMid:=((y2-y1) div 2);

  case pointNum of
    1 :result:=Point(x1,y1);
    2 :result:=Point(x2,y1);
    3 :result:=Point(x1,y2);
    4 :result:=Point(x2,y2);
    5 :result:=Point(x1+xMid,y1+yMid);
    6 :result:=Point(x1+xMid,y1-yMid);
    7 :result:=Point(x1+xMid,y1);
    8 :result:=Point(x1,y1+ymid);
    9 :result:=Point(x1-xMid,y1+yMid);
    10:result:=Point(x1+xMid,y2+yMid);
    11:result:=Point(x1+xMid,y2);
    12:result:=Point(x2+xMid,y1+yMid);
    13:result:=Point(x2,y1+yMid);
  end;
end;

procedure TForm2.Button1Click(Sender: TObject);
begin
  //Reset Map
  FillChar(map,SizeOf(map),0);
  Depth:=0;
  finish:=false;
  InitMap;
  RandSeed:=StrToInt(ESeed.Text);
  repeat
    Square;
    Diamond;
  until finish;
  DumpMapToFile('1.txt');
  Normalize;
  //DumpMapToFile('2.txt');
  Draw
end;

function TForm2.getMapColor(const c:Byte):TAlphaColor;
Begin
  Result:=0;
  if c<SWater.Value then
    Begin
      TAlphaColorRec(Result).R:=0;
      TAlphaColorRec(Result).G:=0;
      TAlphaColorRec(Result).B:=c;

    End
      else
        if c>Ssnow.value then
          Begin
            TAlphaColorRec(Result).R:=c;
            TAlphaColorRec(Result).G:=c;
            TAlphaColorRec(Result).B:=c;
          End
            else
              Begin
                TAlphaColorRec(Result).R:=0;
                TAlphaColorRec(Result).G:=c;
                TAlphaColorRec(Result).B:=0;
              End;
  TAlphaColorRec(Result).A:=255;
End;

procedure TForm2.Normalize;
  var x,y:Word;Ds,Dy:Single;
begin
  //get min and max value
  mapMin:=10000;
  mapMax:=-10000;
  for y := 0 to mapSize do
    for x := 0 to mapSize do
      Begin
        if map[x,y]<mapMin then mapMin:=map[x,y];
        if map[x,y]>mapMax then mapMax:=map[x,y];
      End;
  //Rise ground
    Begin
      for y := 0 to mapSize do
        for x := 0 to mapSize do
          if mapMin<0 then
            map[x,y]:=map[x,y]+Abs(mapMin)
              else
                if mapMin>0 then
                  map[x,y]:=map[x,y]-mapMin;
      mapMax:=mapMax-mapMin;
      mapMin:=0;
    End;
  if mapMax-mapMin<>0 then
    Ds:=1/(mapMax-mapMin)
      else
        Ds:=1;
  for y := 0 to mapSize do
    for x := 0 to mapSize do
      if not ChNormalize.IsChecked then
        normalized[x,y]:=map[x,y]
          else
            if ChSqr.isChecked then
              normalized[x,y]:=Sqr(map[x,y]*Ds)
                else
                  normalized[x,y]:=map[x,y]*Ds
end;

procedure TForm2.Panel2Paint(Sender: TObject; Canvas: TCanvas;
  const ARect: TRectF);
begin
  Draw;
end;

procedure TForm2.ChSqrChange(Sender: TObject);
begin
  Normalize;
  Draw
end;

function TForm2.compress(const c: Single):Byte;
begin
  if ChNormalize.IsChecked then
    result:=Round(c*255)
      else
        result:=Round(c*(255/MapMax-MapMin))
end;

procedure TForm2.Draw;
  var x,y:Word;
      dx,dy:Single;
begin
 CreateMesh;
 Cube1.Height:=SWater.Value;
 Cube1.Position.Y:=0.5-SWater.Value/255;
 //Cube1.Scale.Y:=SWater.Value/130;
 {
  dx:=Panel2.Width/mapSize;
  dy:=Panel2.Height/mapSize;
  Panel2.Canvas.BeginScene;
  Panel2.Canvas.Fill.Color:=TAlphaColorRec.Black;
  Panel2.Canvas.FillRect(RectF(Panel2.Position.X,Panel2.Position.Y,Panel2.Position.X+Panel2.Width,Panel2.Position.Y+Panel2.Height),0,0,[],1);
  for y := 0 to mapSize do
    for x := 0 to mapSize do
      Begin
        //Canvas.Stroke.Kind:=TBrushKind.None;
        Panel2.Canvas.Fill.Kind:=TBrushKind.Solid;
        Panel2.Canvas.Fill.Color:=GetMapColor(Compress(Normalized[x,y]));
        Panel2.Canvas.FillRect(RectF((x-1)*dx+Panel2.Position.X,(y-1)*dy+Panel2.Position.Y,x*dx+1+Panel2.Position.X,y*dy+1+Panel2.Position.Y),0,0,[],1);
      End;
  Panel2.Canvas.EndScene;
  }
end;

procedure TForm2.InitMap;
Begin
  map[0,0]:=StrToInt(E1P.text);
  map[mapSize,0]:=StrToInt(E2P.text);
  map[0,mapSize]:=StrToInt(E3P.text);
  map[mapSize,mapSize]:=StrToInt(E4P.text);
End;

procedure TForm2.Mesh1MouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; var Handled: Boolean);
begin
  Camera1.Position.Z:=Camera1.Position.Z+(WheelDelta/100)
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  RandSeed:=1;
  //CreateMesh;
end;

procedure TForm2.FormShow(Sender: TObject);
begin
  Button1.OnClick(Self)
end;

procedure TForm2.DumpMapToFile(const FileName:String);
  var x,y:Word;
  F:TextFile;
begin
  AssignFile(F,'C:\'+Filename);
  Rewrite(F);
  for y := 0 to mapSize do
    Begin
      for x := 0 to mapSize do
        if (Map[x,y]<-10) then Write(F,'',Round(Map[x,y]))
          else if (Map[x,y]<0) then Write(F,' ',Round(Map[x,y]))
           else if (Map[x,y]<10) then Write(F,'  ',Round(Map[x,y]))
            else if (Map[x,y]<100) then Write(F,' ',Round(Map[x,y]))
              else Write(F,Round(Map[x,y]));
      Writeln(F,'');
    End;
  CloseFile(F);
end;

end.
