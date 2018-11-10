unit dpSource;

interface

uses dpTokens;

//debugging: prevent step-into when debugging
{$D-}
{$L-}

type
  TDParseSourceFile=class(TObject)
  private
    FTIndex,FTLast,FTLength:integer;
    FLineIndex,FFileSize,FErrors:cardinal;
    FTContent:boolean;
    FTokens:TDParseTokenList;
    FSource:UTF8String;
    FFilePath:string;
    FFileTime:TDateTime;
  public
    procedure LoadFromFile(const FilePath:string);
    function Done:boolean;
    //function NextToken(var tt:TDParseTokenType):boolean;
    function Token:TDParseTokenType;
    function IsNext(tt:TDParseTokenType):boolean; overload;//advances index on true!
    function IsNext(const tt:array of TDParseTokenType):boolean; overload;//advances index ONLY ONE on true!
    function IsNextLabel(const Lbl:UTF8String):boolean; //advances index on true!
    procedure Expect(tt:TDParseTokenType; Silent:boolean=false);
    function GetID: UTF8String;
    function GetRaw: UTF8String;
    function GetStr: UTF8String;
    procedure Error(const msg: string);
    function SrcPos:TSrcPos;
    property FilePath:string read FFilePath;
    property FileSize:cardinal read FFileSize;
    property FileTime:TDateTime read FFileTime;
    property LineIndex:cardinal read FLineIndex;
  end;

implementation

uses SysUtils, Windows, Classes;

const
  DefaultLineIndex=1000;//TODO: enforce max line length

{ TDParseSourceFile }

procedure TDParseSourceFile.LoadFromFile(const FilePath: string);
var
  f:TFileStream;
  fi:TByHandleFileInformation;
  st:TSystemTime;
  i:integer;
  x:AnsiString;
  y:WideString;
  z:word;
begin
  //TODO: writeln(FilePath);
  FFilePath:=FilePath;
  //load file
  f:=TFileStream.Create(FilePath,fmOpenRead or fmShareDenyWrite);
  try

    if GetFileInformationByHandle(f.Handle,fi) and
      FileTimeToSystemTime(fi.ftLastWriteTime,st) then
      FFileTime:=SystemTimeToDateTime(st) //FileTimeToLocalFileTime?
    else
      FFileTime:=0.0;//Now?
    i:=f.Size;
    FFileSize:=i;
    f.Read(z,2);
    if z=$FEFF then //UTF16 byte order mark
     begin
      dec(i,2);
      SetLength(y,i div 2);
      f.Read(y[1],i);
      FSource:=UTF8Encode(y);
     end
    else
    if z=$BBEF then //UTF-8 byte order mark
     begin
      z:=0;
      f.Read(z,1);
      //assert z=$00BF
      f.Read(FSource[1],i-3);
     end
    else
     begin
      f.Position:=0;
      SetLength(x,i);
      f.Read(x[1],i);
      FSource:=UTF8String(x);
     end;
  finally
    f.Free;
  end;
  //TODO: EOL's here and determine best SrcPosLineIndex?
  FLineIndex:=DefaultLineIndex;
  //parse data
  FTokens:=DParseTokenize(FSource,FLineIndex);
  FTLength:=Length(FTokens);
  FTIndex:=0;
  FTLast:=0;
  FErrors:=0;
end;

function TDParseSourceFile.Done: boolean;
begin
  Result:=FTIndex>=FTLength;
end;

function TDParseSourceFile.Token: TDParseTokenType;
begin
  if FTContent then inc(FTIndex);
  if FTIndex<FTLength then
   begin
    Result:=FTokens[FTIndex].Token;
    FTLast:=FTIndex;
    FTContent:=Result<tt_Fixed;
    if not FTContent then inc(FTIndex);
   end
  else
   begin
    Error('unexpected end of file');
    Result:=tt_Unknown;
   end;
end;

function TDParseSourceFile.IsNext(tt: TDParseTokenType): boolean;
begin
  if FTIndex<FTLength then
   begin
    Result:=FTokens[FTIndex].Token=tt;
    if Result then
     begin
      FTLast:=FTIndex;
      FTContent:=FTokens[FTIndex].Token<tt_Fixed;
      if not FTContent then inc(FTIndex);
     end;
   end
  else
    Result:=false;
end;

function TDParseSourceFile.IsNext(const tt: array of TDParseTokenType): boolean;
var
  i,l:integer;
begin
  l:=Length(tt);
  if FTIndex+l>FTLength then Result:=false else
   begin
    i:=0;
    while (i<>l) and (FTokens[FTIndex+i].Token=tt[i]) do inc(i);
    Result:=i=l;
    if Result then
     begin
      FTLast:=FTIndex;
      FTContent:=FTokens[FTIndex].Token<tt_Fixed;
      if not FTContent then inc(FTIndex);
     end;
   end;
end;

function TDParseSourceFile.IsNextLabel(const Lbl: UTF8String): boolean;
begin
  //assert Lbl=LowerCase(Lbl)
  if (FTIndex<FTLength) and (FTokens[FTIndex].Token=ttIdentifier) and
    (LowerCase(Copy(FSource,FTokens[FTIndex].Index,FTokens[FTIndex].Length))=Lbl) then
   begin
    Result:=true;
    FTLast:=FTIndex;
    FTContent:=false;//not expecting GetID,GetRaw
    inc(FTIndex);
   end
  else
    Result:=false;
end;

procedure TDParseSourceFile.Expect(tt: TDParseTokenType; Silent: boolean);
begin
  //assert not FContent
  //assert tt>=tt_Fixed
  if (FTIndex<FTLength) and (FTokens[FTIndex].Token=tt) then
   begin
    FTLast:=FTIndex;
    FTContent:=false;
    inc(FTIndex);
   end
  else
    if not Silent then
      if FTIndex<FTLength then
        Error('Expected "'+DParseTokenText[tt]+'", found "'+
          DParseTokenText[FTokens[FTIndex].Token]+'"')
      else
        Error('Expected "'+DParseTokenText[tt]+'"');
end;

function TDParseSourceFile.GetID: UTF8String;
begin
  if (FTIndex<FTLength) and (FTokens[FTIndex].Token=ttIdentifier) then
    Result:=GetRaw
  else
    Error('Identifier expected ('+DParseTokenText[FTokens[FTIndex].Token]+')');
end;

function TDParseSourceFile.GetRaw: UTF8String;
begin
  Result:=Copy(FSource,FTokens[FTIndex].Index,FTokens[FTIndex].Length);
  FTLast:=FTIndex;
  FTContent:=false;
  inc(FTIndex);
end;

function TDParseSourceFile.GetStr: UTF8String;
var
  i,j,r:cardinal;
  a:byte;
begin
  //assert FTIndex<FTLength
  //assert FTokens[FTIndex].Token=ttStringLiteral
  r:=0;
  SetLength(Result,FTokens[FTIndex].Length);
  i:=FTokens[FTIndex].Index;
  j:=i+FTokens[FTIndex].Length;
  while i<j do
    case FSource[i] of
      '''':
       begin
        inc(i);
        while (i<j) and (FSource[i]<>'''') do
         begin
          inc(r);
          Result[r]:=FSource[i];
          inc(i);
         end;
        if (i<j) then inc(i);
        if (i<j) and (FSource[i]='''') then
         begin
          inc(r);
          Result[r]:='''';
         end;
       end;
      '#':
       begin
        inc(i);
        a:=0;//TODO: unicode?
        if (i<j) and (FSource[i]='$') then
         begin
          inc(i);
          while i<j do
            case FSource[i] of
              '0'..'9':
               begin
                a:=a*16+(byte(FSource[i]) and $0F);
                inc(i);
               end;
              'A'..'F','a'..'f':
               begin
                a:=a*16+9+(byte(FSource[i]) and $07);
                inc(i);
               end;
              else
               begin
                i:=j;
                Error('Unsupported string syntax');
               end;
            end;
         end
        else
         begin
          while (i<j) and (FSource[i] in ['0'..'9']) do
           begin
            a:=a*10+(byte(FSource[i]) and $0F);
            inc(i);
           end;
         end;
        inc(r);
        Result[r]:=char(a);
       end;
      else
       begin
        Error('Unsupported string syntax');
        i:=j;
       end;
    end;
  SetLength(Result,r);
  FTContent:=false;
  inc(FTIndex);
end;

procedure TDParseSourceFile.Error(const msg: string);
var
  x,y:cardinal;
begin
  inc(FErrors);
  //TODO: display FFilePath here relative to 'project root'?
  //asm int 3 end;
  if FTLast<FTLength then
   begin
    x:=FTokens[FTLast].SrcPos div FLineIndex;
    y:=FTokens[FTLast].SrcPos mod FLineIndex;
    //TODO: config switch append code snippet
//    if FTokens[FTLast].Length>40 then s:=' "'+Copy(FSource,FTokens[FTLast].Index,40)+'...'
//      else s:=' "'+Copy(FSource,FTokens[FTLast].Index,FTokens[FTLast].Length)+'"';
    WriteError(Format('%s(%d:%d): %s',[FFilePath,x,y,msg]));//Index?
   end
  else
   begin
    //x:=0;
    //y:=0;
    WriteError(Format('%s(EOF): %s',[FFilePath,msg]));
   end;
  //raise?
  //TODO: if @FOnError<>nil then FOnError(Self,x,y,msg);
end;

function TDParseSourceFile.SrcPos: TSrcPos;
begin
  if FTLast<FTLength then
    Result:=FTokens[FTLast].SrcPos
  else
    Result:=0;
end;

end.
