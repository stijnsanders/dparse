unit dpData;

interface

uses DataLank, dpNodes, dpTokens, dpSource;

type
  TDParseData=class(TObject)
  private
    FData:TDataConnection;
    FFile:TDParseSourceFile;
    FSourceID:TNodeIndex;
  public
    Locals:array of TNodeIndex;
    //TODO: Locals private, property, procedure AddLocal

    constructor Create(Data:TDataConnection;SourceFile:TDParseSourceFile;
      SourceID:TNodeIndex);
    //destructor Destroy; override;

    function iNode(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
      Flags:cardinal;SrcPos:TSrcPos):TNodeIndex;
    function iNodeT(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
      Flags:cardinal;SrcPos:TSrcPos;ValueTypeID:TNodeIndex):TNodeIndex;
    function iNodeI(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
      Flags:cardinal;SrcPos:TSrcPos;ValueTypeID:TNodeIndex;IValue:integer):TNodeIndex;
    function iNodeS(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
      Flags:cardinal;SrcPos:TSrcPos;ValueTypeID:TNodeIndex;const SValue:UTF8String):TNodeIndex;
    function iNode1(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
      Flags:cardinal;SrcPos:TSrcPos;Node1:TNodeIndex):TNodeIndex;
    function iNode2(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
      Flags:cardinal;SrcPos:TSrcPos;Node1,Node2:TNodeIndex):TNodeIndex;
    function iNode3(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
      Flags:cardinal;SrcPos:TSrcPos;Node1,Node2,Node3:TNodeIndex):TNodeIndex;
    procedure sNode1(ID1,ID2:TNodeIndex);
    procedure sNode2(ID1,ID2:TNodeIndex);
    procedure sNode3(ID1,ID2:TNodeIndex);
    procedure sNodeF(ID:TNodeIndex;Flags:integer);
    procedure sNodeT(ID1,ID2:TNodeIndex);
    procedure sNodeP(ID1,ID2:TNodeIndex);

    function iLookup(const Name:UTF8String):TNodeIndex;
    function iLookup1(ParentID:TNodeIndex;const Name:UTF8String):TNodeIndex;

    property Data:TDataConnection read FData;
    property SourceFile:TDParseSourceFile read FFile;
  end;

procedure DParseInitData(Data:TDataConnection);

implementation

uses SysUtils;

procedure DParseInitData(Data:TDataConnection);
begin
  Data.Execute(
    'create table SourceFile ('+
    ' id integer primary key autoincrement,'+
    ' filename varchar(1024) not null,'+
    ' filepath varchar(1024) not null,'+
    ' filesize int not null,'+
    ' filedate datetime not null)');
  Data.Execute(
    'create table Node ('+
    ' id integer primary key autoincrement,'+
    ' sourcefile_id integer null,'+
    ' x integer null,'+
    ' y integer null,'+
    ' nodetype_id integer not null,'+
    ' parent_id integer null,'+
    ' name varchar(64) null collate nocase,'+
    ' flags integer null,'+
    ' valuetype_id integer null,'+
    ' ivalue integer null,'+
    ' svalue text null,'+
    ' node1 integer null,'+
    ' node2 integer null,'+
    ' node3 integer null,'+
    ' constraint FK_Node_SourceFile foreign key (sourcefile_id)'+
    ' references SourceFile (id))');
{
  FData.Execute(
    'create unique index IX_Node on Node (parent_id,name)');
}

end;

{ TDParseData }

constructor TDParseData.Create(Data:TDataConnection;
  SourceFile:TDParseSourceFile;SourceID:TNodeIndex);
begin
  inherited Create;
  FData:=Data;
  FFile:=SourceFile;
  FSourceID:=SourceID
end;

function TDParseData.iNode(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
  Flags:cardinal;SrcPos:TSrcPos):TNodeIndex;
begin
  Result:=FData.Insert('Node',
    ['sourcefile_id',FSourceID
    ,'x',SrcPos div FFile.LineIndex
    ,'y',SrcPos mod FFile.LineIndex
    ,'nodetype_id',NodeType
    ,'parent_id',ParentID
    ,'name',Name
    ,'flags',Flags
    ],'id');
end;

function TDParseData.iNodeT(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
  Flags:cardinal;SrcPos:TSrcPos;ValueTypeID:TNodeIndex):TNodeIndex;
begin
  Result:=FData.Insert('Node',
    ['sourcefile_id',FSourceID
    ,'x',SrcPos div FFile.LineIndex
    ,'y',SrcPos mod FFile.LineIndex
    ,'nodetype_id',NodeType
    ,'parent_id',ParentID
    ,'name',Name
    ,'flags',Flags
    ,'valuetype_id',ValueTypeID
    ],'id');
end;

function TDParseData.iNodeI(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
  Flags:cardinal;SrcPos:TSrcPos;ValueTypeID:TNodeIndex;IValue:integer):TNodeIndex;
begin
  Result:=FData.Insert('Node',
    ['sourcefile_id',FSourceID
    ,'x',SrcPos div FFile.LineIndex
    ,'y',SrcPos mod FFile.LineIndex
    ,'nodetype_id',NodeType
    ,'parent_id',ParentID
    ,'name',Name
    ,'flags',Flags
    ,'valuetype_id',ValueTypeID
    ,'ivalue',IValue
    ],'id');
end;

function TDParseData.iNodeS(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
  Flags:cardinal;SrcPos:TSrcPos;ValueTypeID:TNodeIndex;const SValue:UTF8String):TNodeIndex;
begin
  Result:=FData.Insert('Node',
    ['sourcefile_id',FSourceID
    ,'x',SrcPos div FFile.LineIndex
    ,'y',SrcPos mod FFile.LineIndex
    ,'nodetype_id',NodeType
    ,'parent_id',ParentID
    ,'name',Name
    ,'flags',Flags
    ,'valuetype_id',ValueTypeID
    ,'svalue',SValue
    ],'id');
end;

function TDParseData.iNode1(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
  Flags:cardinal;SrcPos:TSrcPos;Node1:TNodeIndex):TNodeIndex;
begin
  Result:=FData.Insert('Node',
    ['sourcefile_id',FSourceID
    ,'x',SrcPos div FFile.LineIndex
    ,'y',SrcPos mod FFile.LineIndex
    ,'nodetype_id',NodeType
    ,'parent_id',ParentID
    ,'name',Name
    ,'flags',Flags
    ,'node1',Node1
    ],'id');
end;

function TDParseData.iNode2(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
  Flags:cardinal;SrcPos:TSrcPos;Node1,Node2:TNodeIndex):TNodeIndex;
begin
  Result:=FData.Insert('Node',
    ['sourcefile_id',FSourceID
    ,'x',SrcPos div FFile.LineIndex
    ,'y',SrcPos mod FFile.LineIndex
    ,'nodetype_id',NodeType
    ,'parent_id',ParentID
    ,'name',Name
    ,'flags',Flags
    ,'node1',Node1
    ,'node2',Node2
    ],'id');
end;

function TDParseData.iNode3(NodeType:TNodeType;const Name:UTF8String;ParentID:TNodeIndex;
  Flags:cardinal;SrcPos:TSrcPos;Node1,Node2,Node3:TNodeIndex):TNodeIndex;
begin
  Result:=FData.Insert('Node',
    ['sourcefile_id',FSourceID
    ,'x',SrcPos div FFile.LineIndex
    ,'y',SrcPos mod FFile.LineIndex
    ,'nodetype_id',NodeType
    ,'parent_id',ParentID
    ,'name',Name
    ,'flags',Flags
    ,'node1',Node1
    ,'node2',Node2
    ,'node3',Node3
    ],'id');
end;

procedure TDParseData.sNode1(ID1,ID2:TNodeIndex);
begin
  FData.Execute('UPDATE Node SET node1=? WHERE id=?',[ID2,ID1]);
end;

procedure TDParseData.sNode2(ID1,ID2:TNodeIndex);
begin
  FData.Execute('UPDATE Node SET node2=? WHERE id=?',[ID2,ID1]);
end;

procedure TDParseData.sNode3(ID1,ID2:TNodeIndex);
begin
  FData.Execute('UPDATE Node SET node3=? WHERE id=?',[ID2,ID1]);
end;

procedure TDParseData.sNodeF(ID:TNodeIndex;Flags:integer);
begin
  FData.Execute('UPDATE Node SET flags=flags|? WHERE id=?',[Flags,ID]);
end;

procedure TDParseData.sNodeT(ID1,ID2:TNodeIndex);
begin
  FData.Execute('UPDATE Node SET valuetype_id=? WHERE id=?',[ID2,ID1]);
end;

procedure TDParseData.sNodeP(ID1,ID2:TNodeIndex);
begin
  FData.Execute('UPDATE Node SET parent_id=? WHERE id=?',[ID2,ID1]);
end;

function TDParseData.iLookup(const Name: UTF8String): TNodeIndex;
var
  i:integer;
  qr:TQueryResult;
begin
  Result:=0;
  i:=0;
  while (Result=0) and (i<Length(Locals)) do
   begin
    qr:=TQueryResult.Create(FData,
      'select id from Node where parent_id=? and name=?',
      [Locals[i],Name]);
    try
      if qr.Read then
       begin
        Result:=qr.GetInt('id');
        //TODO: if qr.Read then Error('Duplicate identifier')
       end;
    finally
      qr.Free;
    end;
    inc(i);
   end;
  if Result=0 then
    Result:=iNode(ntExternal,Name,Locals[0],0,SourceFile.SrcPos);
end;

function TDParseData.iLookup1(ParentID: TNodeIndex;
  const Name: UTF8String): TNodeIndex;
var
  qr:TQueryResult;
begin
  Result:=0;//default
  if ParentID<>0 then
   begin
    qr:=TQueryResult.Create(Data,'select id from Node where parent_id=? and name=?',[ParentID,Name]);
    try
      if qr.Read then
        Result:=qr.GetInt('id');
      //else error?
    finally
      qr.Free;
    end;
   end;
  //else error?
end;


end.
