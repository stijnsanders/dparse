unit dpConst;

interface

uses dpTokens, dpNodes, dpData;

function ParseType(d:TDParseData;const n:UTF8String;
  SubjectID:TNodeIndex;Flags:cardinal):TNodeIndex;
procedure ParseConst(d:TDParseData;SubjectID:TNodeIndex;Flags:cardinal);

implementation

uses dpSource;

function ParseType(d:TDParseData;const n:UTF8String;
  SubjectID:TNodeIndex;Flags:cardinal):TNodeIndex;
var
  SourceFile:TDParseSourceFile;
  SrcPos:TSrcPos;
begin
  Result:=0;//default
  SourceFile:=d.SourceFile;
  case SourceFile.Token of
    rwString:
      //Result:=iNode(ntTypeString,'string',SubjectID,Flags,SrcPos);
      Result:=d.iLookup('string');
    ttIdentifier:
      Result:=d.iLookup(SourceFile.GetID);
      //TODO: IsNext(ttPeriod)

    //ttPOpen://enumeration?
    //rwRecord://?
    //rwPacked://?

    rwArray:
     begin
      SrcPos:=SourceFile.SrcPos;
      if SourceFile.IsNext(ttBOpen) then
       begin
        //parse range
        repeat
          //TODO: start array dimension
          case SourceFile.Token of
            ttIntegerLiteral:
             begin
              SourceFile.Expect(ttRange);
              case SourceFile.Token of
                ttIntegerLiteral:;//TODO
                ttIdentifier:;//TODO
                else SourceFile.Error('Unexpected array index syntax');
              end;
             end;
            ttIdentifier:
             begin
              //TODO
              if SourceFile.IsNext(ttRange) then
              case SourceFile.Token of
                ttIntegerLiteral:;//TODO
                ttIdentifier:;//TODO
                else SourceFile.Error('Unexpected array index syntax');
              end;
             end;
          end;
        until not SourceFile.IsNext(ttComma);
        SourceFile.Expect(ttBClose);
       end;
      SourceFile.Expect(rwOf);
      Result:=d.iNodeT(ntArray,n,SubjectID,Flags,SrcPos,ParseType(d,'',0,0));
     end;

    else SourceFile.Error('Unexpected syntax');
  end;
end;

procedure ParseConst(d:TDParseData;SubjectID:TNodeIndex;Flags:cardinal);
type
  TPrecedence=(
    pParentheses,
    pOpAddSub,
    pOpMulDiv,
    pPeriod,
    pUnary,
    p_Unspecified
  );
var
  CStack:array of record
    Precedence:TPrecedence;
    Subject:TNodeIndex;
    Flags,SrcPos:cardinal;
  end;
  CStackSize,CStackIndex:integer;

  procedure Push(Precedence:TPrecedence;Subject:TNodeIndex;Flags:cardinal;SrcPos:TSrcPos);
  begin
    if FStackIndex=FStackSize then
     begin
      //grow
      inc(FStackSize,$400);
      SetLength(FStack,FStackSize);
     end;
    FStack[FStackIndex].Precedence:=Precedence;
    FStack[FStackIndex].Subject:=Subject;
    FStack[FStackIndex].Flags:=Flags;
    FStack[FStackIndex].SrcPos:=SrcPos;
    inc(FStackIndex);
    CurrentID:=0;
    //Result:=Subject;
  end;

  procedure Resolve(MinPrecedence:TPrecedence);
  var
    ObjectID:TNodeIndex;
    Flags,SrcPos:cardinal;
  begin
    while (FStackIndex<>0) and (FStack[FStackIndex-1].Precedence>MinPrecedence) do
     begin
      dec(FStackIndex);//Pop
      ObjectID:=FStack[FStackIndex].Subject;
      Flags:=FStack[FStackIndex].Flags;
      SrcPos:=FStack[FStackIndex].SrcPos;
      case FStack[FStackIndex].Precedence of

        else
          raise Exception.Create('Unknown resolution');
      end;
      FStack[FStackIndex].Precedence:=p__;//DEBUG
     end;
  end;

  //conditional pop!
  function Pop(CheckPrecedence:TPrecedence;var ID:TNodeIndex):boolean;
  begin
    Resolve(CheckPrecedence);
    if FStackIndex=0 then
      Result:=false //error?
    else
      if FStack[FStackIndex-1].Precedence=CheckPrecedence then
       begin
        dec(FStackIndex);
        ID:=FStack[FStackIndex].Subject;
        FStack[FStackIndex].Precedence:=p__;//DEBUG
        Result:=true;
       end
      else
        Result:=false;
  end;

  function Top(var ID:TNodeIndex;var SrcPosX:TSrcPos):TPrecedence;
  begin
    if FStackIndex=0 then
     begin
      Result:=p_Unspecified;
      ID:=0;
      SrcPosX:=0;
     end
    else
     begin
      Result:=FStack[FStackIndex-1].Precedence;
      ID:=FStack[FStackIndex-1].Subject;
      SrcPosX:=FStack[FStackIndex-1].SrcPos;
     end;
  end;

  procedure Expose(ObjectID:TNodeIndex);
  begin
    if CurrentID<>0 then
      SourceFile.Error('Operator expected');
    CurrentID:=ObjectID;
  end;

var
  SourceFile:TDParseSourceFile;
  n:UTF8String;
  ID,CID,CTypeID:TNodeIndex;
  SrcPos:TSrcPos;
begin
  SourceFile:=d.SourceFile;
  while SourceFile.IsNext([ttIdentifier]) do
   begin
    n:=SourceFile.GetID;
    SrcPos:=SourceFile.SrcPos;
    if SourceFile.IsNext([ttColon]) then
      CTypeID:=ParseType(d,'',0,0)
    else
      CTypeID:=0;//?
    SourceFile.Expect(ttOpEQ);
    CID:=d.iNodeT(ntConstant,n,SubjectID,Flags,SrcPos,CTypeID);

    raise Exception.Create('TODO');

   end;
end;

end.
