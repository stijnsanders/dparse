unit dpParse;

interface

uses DataLank, dpData, dpNodes, dpSource;

function DParseSource(Data:TDataConnection;SourceFile:TDParseSourceFile):TNodeIndex;

//forward declarations for use below only
procedure ParseImperative(d:TDParseData;ProgramID:TNodeIndex;
  SingleStatement:boolean;CodeBlockID:TNodeIndex);
procedure ParseCase(d:TDParseData;SubjectID:TNodeIndex);

implementation

uses SysUtils, dpTokens, dpConst;

function DParseSource(Data:TDataConnection;SourceFile:TDParseSourceFile):TNodeIndex;
var
  SourceID:TNodeIndex absolute Result;
  GlobalDeclFlags:cardinal;
  d:TDParseData;

  procedure ParseUsesClause(SubjectID:TNodeIndex);
  var
    n:UTF8String;
  begin
    repeat
      n:=SourceFile.GetID;
      if SourceFile.IsNext([rwIn,ttStringLiteral]) then
        d.iNodeS(ntUses,n,SubjectID,GlobalDeclFlags,SourceFile.SrcPos,0,SourceFile.GetStr)
      else
        d.iNode(ntUses,n,SubjectID,GlobalDeclFlags,SourceFile.SrcPos);
      //TODO: import/resolve, add to locals
    until not SourceFile.IsNext(ttComma);
    SourceFile.Expect(ttSemiColon);
  end;

  procedure ParseVars(SubjectType:TNodeType;SubjectID:TNodeIndex;Flags:cardinal);
  var
    n:UTF8String;
    i,j,l:integer;
    TypeID:TNodeIndex;
  begin
    n:='';
    repeat
      n:=n+','+SourceFile.GetID;
    until not SourceFile.IsNext(ttComma);
    SourceFile.Expect(ttColon);
    TypeID:=ParseType('',0,0);
    i:=1;
    l:=Length(n);
    while i<=l do
     begin
      inc(i);//skip ','
      j:=i;
      while (i<=l) and (n[i]<>',') do inc(i);
      d.iNodeT(SubjectType,Copy(n,j,i-j),SubjectID,Flags,SourceFile.SrcPos,TypeID);
     end;
    //SourceFile.Expect(ttSemiColon);//done by caller!
  end;

  function GetSuffix(var Flags:cardinal;const Lbl:UTF8String;Flag:cardinal):boolean;
  begin
    //if SourceFile.IsNext(Token) then
    if SourceFile.IsNextLabel(Lbl) then
     begin
      SourceFile.Expect(ttSemiColon);
      Flags:=Flags or Flag;
      Result:=true
     end
    else
      Result:=false;
  end;
  
  procedure ParseSignature(SubjectType:TNodeType;SubjectID:TNodeIndex);
  var
    f:cardinal;
  begin
    if SourceFile.IsNext(ttPOpen) then
      if not SourceFile.IsNext(ttPClose) then
        if SubjectType=ntDestructor then
          SourceFile.Error('No arguments expected on destructor')
        else
          while true do
           begin
            //modifiers
            if SourceFile.IsNext(rwConst) then f:=ArgMod_Const else
            if SourceFile.IsNext(rwVar) then f:=ArgMod_Var else
            if SourceFile.IsNext(rwOut) then f:=ArgMod_Out else
              f:=0;
            //TODO: var/out/in/const
            ParseVars(ntArgument,SubjectID,f);
            //TODO: flag untyped argument?
            case SourceFile.Token of
              ttSemiColon:;//next
              ttPClose:break;//done
              else
               begin
                SourceFile.Error('Unexpected syntax');
                break;
               end;
            end;
           end;
    //return type?
    if SubjectType=ntFunction then
      if SourceFile.IsNext(ttColon) then
        d.sNodeT(SubjectID,ParseType('',0,0))
      else
        SourceFile.Error('Function requires result type');
    SourceFile.Expect(ttSemiColon);
    //suffix?

    //TODO: forward?
    //if SubjectID's parent=Locals[0] then if not GetSuffix('forward',???

    f:=0;
    GetSuffix(f,'reintroduce',Method_Reintroduce);
    GetSuffix(f,'overload',Method_Overload);
    if GetSuffix(f,'virtual',Method_Virtual)
    or GetSuffix(f,'dynamic',Method_Dynamic)
    or GetSuffix(f,'override',Method_Override)
    then ;

    if GetSuffix(f,'register',CallConv_Register)
    or GetSuffix(f,'pascal',CallConv_Pascal)
    or GetSuffix(f,'cdecl',CallConv_CDecl)
    or GetSuffix(f,'stdcall',CallConv_StdCall)
    or GetSuffix(f,'safecall',CallConv_SafeCall)
    then ;

    GetSuffix(f,'abstract',Method_Abstract);

    if GetSuffix(f,'platform',Hint_Platform)
    or GetSuffix(f,'deprecated',Hint_Deprecated)
    or GetSuffix(f,'library',Hint_Library)
    then ;

    if f<>0 then d.sNodeF(SubjectID,f);
  end;

  procedure ParseRecord(SubjectID:TNodeIndex);
  begin
    while not SourceFile.IsNext(rwEnd) do
      case SourceFile.Token of

        ttIdentifier:
         begin
          ParseVars(ntVar,SubjectID,0);
          SourceFile.Expect(ttSemiColon);
         end;

        else SourceFile.Error('Unexpected record syntax');
      end;
    //SourceFile.Expect(ttSemiColon);//by caller!
  end;

  procedure ParseClass(SubjectID:TNodeIndex);
  var
    Visibility:cardinal;
  begin
    if SourceFile.IsNext(ttPOpen) then
     begin
      repeat
        d.iNode(ntInheritsImplements,SourceFile.GetID,SubjectID,0,SourceFile.SrcPos);
      until not SourceFile.IsNext(ttComma);
      SourceFile.Expect(ttPClose);
     end;
    //else inherits from TObject?
    Visibility:=Visibility_Public;//Default
    while not SourceFile.IsNext(rwEnd) do
      case SourceFile.Token of

        rwPrivate:  Visibility:=Visibility_Private;
        rwPublic:   Visibility:=Visibility_Public;
        rwProtected:Visibility:=Visibility_Protected;
        rwPublished:Visibility:=Visibility_Published;
        //more?

        ttIdentifier:
         begin
          ParseVars(ntVar,SubjectID,Visibility);
          //TODO: ttOpEq for interface method alias
          SourceFile.Expect(ttSemiColon);
         end;
        rwConstructor:
          ParseSignature(ntConstructor,
            d.iNode(ntConstructor,SourceFile.GetID,SubjectID,Visibility,SourceFile.SrcPos));
        rwDestructor:
          ParseSignature(ntDestructor,
            d.iNode(ntDestructor,SourceFile.GetID,SubjectID,Visibility,SourceFile.SrcPos));
        rwProcedure:
          ParseSignature(ntProcedure,
            d.iNode(ntProcedure,SourceFile.GetID,SubjectID,Visibility,SourceFile.SrcPos));
        rwFunction:
          ParseSignature(ntFunction,
            d.iNode(ntFunction,SourceFile.GetID,SubjectID,Visibility,SourceFile.SrcPos));
        {
        rwProperty:;//TODO
        }
        rwClass:
          case SourceFile.Token of
            rwProcedure:
              ParseSignature(ntClassProcedure,
                d.iNode(ntClassProcedure,SourceFile.GetID,SubjectID,Visibility,SourceFile.SrcPos));
            rwFunction:
              ParseSignature(ntClassFunction,
                d.iNode(ntClassFunction,SourceFile.GetID,SubjectID,Visibility,SourceFile.SrcPos));
            else SourceFile.Error('Unexpected class syntax');
          end;

        else SourceFile.Error('Unexpected class syntax');
      end;
    //SourceFile.Expect(ttSemiColon);//done by caller
  end;

  procedure ParseTypeDecls(SubjectID:TNodeIndex;Flags:cardinal);
  var
    n:UTF8String;
    ID:TNodeIndex;
    SrcPos:TSrcPos;
  begin
    while SourceFile.IsNext([ttIdentifier]) do
     begin
      n:=SourceFile.GetID;
      SourceFile.Expect(ttOpEQ);

      case SourceFile.Token of
        rwString:
          d.iNodeT(ntType,n,SubjectID,Flags,SourceFile.SrcPos,
            d.iLookup('string'));
        ttIdentifier:
          d.iNodeT(ntType,n,SubjectID,Flags,SourceFile.SrcPos,
            d.iLookup(SourceFile.GetID));

        ttPOpen://enumeration
         begin
          ID:=d.iNode(ntEnumeration,n,SubjectID,Flags,SourceFile.SrcPos);
          Flags:=0;
          repeat
            n:=SourceFile.GetID;
            SrcPos:=SourceFile.SrcPos;
            if SourceFile.IsNext(ttOpEQ) then
             begin
              case SourceFile.Token of
                ttIntegerLiteral:Flags:=StrToInt(SourceFile.GetRaw);
                //ttIdentifier://TODO: constants
                else SourceFile.Error('Invalid enumeration constant');
              end;
             end;

            //TODO: lookup, enforce not declared before
            //TODO: system word sized constant integer type (0 for now)
            d.iNodeI(ntEnumValue,n,ID,0,SrcPos,0,Flags);
            inc(Flags);
          until not SourceFile.IsNext(ttComma);
          SourceFile.Expect(ttPClose);
         end;

        rwRecord:
          ParseRecord(d.iNode(ntRecord,n,SubjectID,Flags,SourceFile.SrcPos));

        rwPacked:
         begin
          SourceFile.Expect(rwRecord);
          ParseRecord(d.iNode(ntRecord,n,SubjectID,Flags or Record_Packed,SourceFile.SrcPos));
         end;

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
          d.iNodeT(ntArray,n,SubjectID,Flags,SrcPos,ParseType('',0,0));
         end;

        //rwObject:;//TODO

        rwClass:
          ParseClass(d.iNode(ntRecord,n,SubjectID,Flags,SourceFile.SrcPos));

        //rwInterface:

        else SourceFile.Error('Unexpected syntax');
      end;
      SourceFile.Expect(ttSemiColon);
     end;
  end;

  procedure ParseNestedProgram(ProgramID:TNodeIndex);
  var
    tt:TDParseTokenType;
    n:UTF8String;
    ID:TNodeIndex;
  begin
    tt:=tt_Unknown;
    while true do
      case SourceFile.Token of

        rwType:tt:=rwType;
        rwConst:tt:=rwConst;
        rwVar:tt:=rwVar;

        ttIdentifier:
          case tt of
            rwType:
              ParseTypeDecls(ProgramID,0);
            rwVar:
             begin
              ParseVars(ntVar,ProgramID,0);
              SourceFile.Expect(ttSemiColon);
             end;
            rwConst:
              ParseConst(d,ProgramID,0);
            else
              SourceFile.Error('Unexpected syntax');//break?
          end;

        rwProcedure:
         begin
          n:=SourceFile.GetID;
          ID:=d.iLookup(n);
          if ID=0 then ID:=d.iNode(ntProcedure,n,ProgramID,0,SourceFile.SrcPos);
          ParseSignature(ntProcedure,ID);
          ParseNestedProgram(ID);
         end;
        rwFunction:
         begin
          n:=SourceFile.GetID;
          ID:=d.iLookup(n);
          if ID=0 then ID:=d.iNode(ntFunction,n,ProgramID,0,SourceFile.SrcPos);
          ParseSignature(ntFunction,ID);
          ParseNestedProgram(ID);
         end;

        rwBegin:
         begin
          ParseImperative(d,ProgramID,false,
            d.iNode(ntBeginEnd,'',ProgramID,0,SourceFile.SrcPos));
          SourceFile.Expect(ttSemiColon);
          break;//done
         end;

        rwEnd:
         begin
          d.iNode(ntBeginEnd,'',ProgramID,0,SourceFile.SrcPos);
          break;//empty body!
         end;

        else
         begin
          SourceFile.Error('Unexpected syntax');
          break;
         end;
      end;
  end;


var
  ID:TNodeIndex;
  nt:TNodeType;
  n,m:UTF8String;

begin
  SourceID:=0;//default
  if SourceFile.Done then
   begin
    SourceFile.Error('Unexpected end of file, expected "unit", "program" or "library"');
    Exit;
   end;
  case SourceFile.Token of
    rwUnit:nt:=ntUnit;
    rwProgram:nt:=ntProgram;
    rwLibrary:nt:=ntLibrary;
    else nt:=nt_Unknown;
  end;
  if (nt=nt_Unknown) or not(SourceFile.IsNext(ttIdentifier)) then
   begin
    SourceFile.Error('Unexpected start of file, expected "unit", "program" or "library"');
    Exit;
   end;
  n:=SourceFile.GetID;
  SourceFile.Expect(ttSemiColon);

  SourceID:=Data.Insert('SourceFile',
    ['filename',n
    ,'filepath',SourceFile.FilePath
    ,'filesize',SourceFile.FileSize
    ,'filedate',SourceFile.FileTime
    ],'id');
  d:=TDParseData.Create(Data,SourceFile,SourceID);
  try

    SetLength(d.Locals,1);
    d.Locals[0]:=Data.Insert('Node',
      ['sourcefile_id',SourceID
      ,'x',SourceFile.SrcPos div SourceFile.LineIndex
      ,'y',SourceFile.SrcPos mod SourceFile.LineIndex
      ,'nodetype_id',nt
      //,'parent_id',Null//TODO: namespaces
      ,'name',n
      ],'id');


    GlobalDeclFlags:=Declaration_Interface;

    if SourceFile.IsNext(rwUses) then ParseUsesClause(d.Locals[0]);
    if nt=ntUnit then
     begin
      SourceFile.Expect(rwInterface);
      if SourceFile.IsNext(rwUses) then ParseUsesClause(d.Locals[0]);
     end;

    while true do
      case SourceFile.Token of

        rwEnd:
         begin
          SourceFile.Expect(ttPeriod);
          break;//from loop
         end;
        tt_Unknown:break;

        //rwInterface://see above
        rwImplementation:
          if GlobalDeclFlags=Declaration_Implementation then
            SourceFile.Error('Only one implementation section allowed')
          else
           begin
            GlobalDeclFlags:=Declaration_Implementation;
            if SourceFile.IsNext(rwUses) then ParseUsesClause(d.Locals[0]);
           end;


        rwType:
          ParseTypeDecls(d.Locals[0],GlobalDeclFlags);

        //rwConst:
        //rwThreadVar:
        //rwResourceString:

        rwVar:
         begin
          ParseVars(ntVar,d.Locals[0],GlobalDeclFlags);
          SourceFile.Expect(ttSemiColon);
         end;

        rwProcedure:
         begin
          n:=SourceFile.GetID;
          ID:=d.iLookup(n);
          while SourceFile.IsNext(ttPeriod) do
           begin
            m:=SourceFile.GetID;
            ID:=d.iLookup1(ID,m);
            n:=n+'.'+m;
           end;
          //TODO: lookup?
          if ID=0 then ID:=d.iNode(ntProcedure,
            n,d.Locals[0],0,SourceFile.SrcPos);
          //TODO: if already ntBeginEnd then raise
          ParseSignature(ntProcedure,ID);
          if GlobalDeclFlags=Declaration_Implementation then
            ParseNestedProgram(ID);
         end;
        rwFunction:
         begin
          n:=SourceFile.GetID;
          ID:=d.iLookup(n);
          while SourceFile.IsNext(ttPeriod) do
           begin
            m:=SourceFile.GetID;
            ID:=d.iLookup1(ID,m);
            n:=n+'.'+m;
           end;
          //TODO: lookup?
          if ID=0 then ID:=d.iNode(ntFunction,n,d.Locals[0],0,SourceFile.SrcPos);
          //TODO: if already ntBeginEnd then raise
          ParseSignature(ntFunction,ID);
          if GlobalDeclFlags=Declaration_Implementation then
            ParseNestedProgram(ID);
         end;
        rwConstructor:
         begin
          n:=SourceFile.GetID;
          SourceFile.Expect(ttPeriod);
          ID:=d.iNode(ntConstructor,n+'.'+SourceFile.GetID,
            d.iLookup(n),0,SourceFile.SrcPos);
          ParseSignature(ntConstructor,ID);
          if GlobalDeclFlags=Declaration_Implementation then
            ParseNestedProgram(ID)
          else
            SourceFile.Error('Unexpected constructor declaration');
         end;
        rwDestructor:
         begin
          n:=SourceFile.GetID;
          SourceFile.Expect(ttPeriod);
          ID:=d.iNode(ntDestructor,n+'.'+SourceFile.GetID,
            d.iLookup(n),0,SourceFile.SrcPos);
          ParseSignature(ntDestructor,ID);
          if GlobalDeclFlags=Declaration_Implementation then
            ParseNestedProgram(ID)
          else
            SourceFile.Error('Unexpected destructor declaration');
         end;

        //rwInitialization:;
        //rwFinalization:;

        rwBegin:
          if nt=ntProgram then
           begin
            ParseImperative(d,d.Locals[0],false,
              d.iNode(ntBeginEnd,'',d.Locals[0],0,SourceFile.SrcPos));//?'main'
            SourceFile.Expect(ttPeriod);
            break;//from loop
           end
          else
            SourceFile.Error('Unexpected command block');

        else SourceFile.Error('Unexpected syntax');

      end;
  finally
    d.Free;
  end;
end;


procedure ParseImperative(d:TDParseData;ProgramID:TNodeIndex;
  SingleStatement:boolean;CodeBlockID:TNodeIndex);
type
  TPrecedence=(
    p__,//DEBUG

    pCodeBlock,
    pIfWhen,pIfThen,pIfElse,
    pTry,pRaise,
    pCase,
    pWhileEx,
    pWhileDo,

    pCall,pSet,

    pAssignment,
    pParentheses,

    p_List,//see ttComma
    pArgument,pSetElem,

    pOpCompare,
    pOpIn,pRange,

    pOpAddSub,
    pOpMulDiv,

    pPeriod,
    pUnary,

    p_Unspecified
  );
var
  SourceFile:TDParseSourceFile;
  FStack:array of record
    Precedence:TPrecedence;
    Subject:TNodeIndex;
    Flags,SrcPos:cardinal;
  end;
  FStackSize,FStackIndex:integer;
  CurrentID:TNodeIndex;

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

        pArgument:
          if CurrentID=0 then
            SourceFile.Error('Argument missing')
          else
           begin
            d.iNode1(ntArgument,'',ObjectID,0,SourceFile.SrcPos,CurrentID);
            CurrentID:=0;
           end;
        pSetElem:
          if CurrentID=0 then
            SourceFile.Error('Set element missing')
          else
           begin
            d.iNode1(ntSetElem,'',ObjectID,0,Sourcefile.SrcPos,CurrentID);
            CurrentID:=0;
           end;

        pUnary://assert ObjectID=0
          CurrentID:=d.iNode1(ntUnaryOp,DParseTokenText[TDParseTokenType(Flags)],CodeBlockID,0,SrcPos,CurrentID);
        pOpCompare,pOpAddSub,pOpMulDiv://assert ObjectID<>0
          CurrentID:=d.iNode2(ntBinaryOp,DParseTokenText[TDParseTokenType(Flags)],CodeBlockID,0,SrcPos,ObjectID,CurrentID);
        pOpIn:
          CurrentID:=d.iNode2(ntBinaryOp,'in',CodeBlockID,0,SrcPos,ObjectID,CurrentID);
        pRange:
          CurrentID:=d.iNode2(ntBinaryOp,'..',CodeBlockID,0,SrcPos,ObjectID,CurrentID);

        pPeriod:
          CurrentID:=d.iNode2(ntMember,'',CodeBlockID,0,SrcPos,ObjectID,CurrentID);

        pAssignment:
          CurrentID:=d.iNode2(ntAssignment,':=',CodeBlockID,0,SrcPos,ObjectID,CurrentID);

        pRaise:
         begin
          d.iNode1(ntRaise,'',CodeBlockID,0,SrcPos,CurrentID);//if CurrentID=0 'reraise'
          CurrentID:=0;
         end;

        //these should get handled by Pop on proper token:
        pCodeBlock:
          SourceFile.Error('"end" without according "begin"');
        pParentheses,pCall:
          SourceFile.Error('"(" without according ")"');
        pSet:
          SourceFile.Error('Undelimited set');
        pTry:
          SourceFile.Error('"except" or "finally" expected');
        pIfWhen:
          SourceFile.Error('"if" without "then"');
        pIfThen:
          if CurrentID<>0 then
           begin
            d.sNode2(ObjectID,CurrentID);
            CurrentID:=0;
           end;
        pIfElse:
          if CurrentID<>0 then
           begin
            d.sNode3(ObjectID,CurrentID);
            CurrentID:=0;
           end;
        pCase:
          SourceFile.Error('"case" without expression');
        pWhileEx:
          SourceFile.Error('"while" without predicate');
        pWhileDo:
          if CurrentID<>0 then
           begin
            d.sNode2(ObjectID,CurrentID);
            CurrentID:=0;
           end;
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
  ID:TNodeIndex;
  SrcPos:TSrcPos;
  tt:TDParseTokenType;
  n:UTF8String;
begin
  SourceFile:=d.SourceFile;
  SrcPos:=SourceFile.SrcPos;
  FStackSize:=0;
  FStackIndex:=0;
  Push(pCodeBlock,CodeBlockID,0,SrcPos);//sets CurrentID:=0;!!!
  //Locals[]:=ProgramID?

  while FStackIndex<>0 do
   begin
    tt:=SourceFile.Token;
    case tt of

      ttSemiColon:
       begin
        Resolve(pCodeBlock);
        if CurrentID<>0 then
         begin
          //iNode(ntBeginEndStep?
          d.sNodeP(CurrentID,ID);
          CurrentID:=0;
         end;
        if SingleStatement and (FStackIndex=1) then
         begin
          //assert Top()=pCodeBlock
          Pop(pCodeBlock,ID);//FStackIndex:=0; to end loop
         end;
       end;

      ttIdentifier:
       begin
        //TODO:resolve
        Expose(d.iNode(ntCall,SourceFile.GetID,0,0,SourceFile.SrcPos));
       end;
      rwNil:
       begin
        //TODO:resolve
        Expose(d.iNode(ntCall,'nil',0,0,SourceFile.SrcPos));
       end;
      ttIntegerLiteral,ttStringLiteral,ttFloatingPointLiteral:
        Expose(d.iNode(ntConstant,SourceFile.GetRaw,0,cardinal(tt),SourceFile.SrcPos));

      ttOpEQ,ttOpNEQ,ttOpLT,ttOpLTE,ttOpGT,ttOpGTE:
        if CurrentID=0 then
          SourceFile.Error('Comparison left side missing')
        else
         begin
          Resolve(pOpCompare);
          Push(pOpCompare,CurrentID,cardinal(tt),SourceFile.SrcPos);
         end;
      ttOpMul,ttOpDiv:
        if CurrentID=0 then
          SourceFile.Error('Multiplication left side missing')
        else
         begin
          Resolve(pOpMulDiv);
          Push(pOpMulDiv,CurrentID,cardinal(tt),SourceFile.SrcPos);
         end;
      ttOpAdd,ttOpSub:
        if CurrentID=0 then
          Push(pUnary,0,cardinal(tt),SourceFile.SrcPos)
        else
         begin
          Resolve(pOpAddSub);
          Push(pOpAddSub,CurrentID,cardinal(tt),SourceFile.SrcPos);
         end;
      rwNot:
       begin
        Expose(0);
        Push(pUnary,0,cardinal(tt),SourceFile.SrcPos);
       end;
      rwAnd:
        if CurrentID=0 then
          SourceFile.Error('"and" left side missing')
        else
         begin
          Resolve(pOpMulDiv);//!!
          Push(pOpMulDiv,CurrentID,cardinal(tt),SourceFile.SrcPos);
         end;
      rwOr,rwXor:
        if CurrentID=0 then
          SourceFile.Error('"or"/"xor" left side missing')
        else
         begin
          Resolve(pOpAddSub);//!!
          Push(pOpAddSub,CurrentID,cardinal(tt),SourceFile.SrcPos);
         end;

      ttPeriod:
        if CurrentID=0 then
          //TODO?
        else
          //resolve?
          //TODO: lookup
          Push(pPeriod,CurrentID,0,SourceFile.SrcPos);

      rwInherited:
       begin
        if SourceFile.IsNext(ttIdentifier) then n:=SourceFile.GetID else n:='';
        SrcPos:=SourceFile.SrcPos;
        //if SourceFile.IsNext(ttPOpen) then //TODO:
        Expose(d.iNode(ntCallInherited,n,0,0,SrcPos));
       end;

      ttOpAssign:
        if CurrentID=0 then
          SourceFile.Error('Assignment left side missing')
        else
          Push(pAssignment,CurrentID,0,SourceFile.SrcPos);

      ttPOpen://fncall or math parentheses?
        if CurrentID=0 then
          Push(pParentheses,0,0,SourceFile.SrcPos)
        else
         begin
          ID:=d.iNode1(ntCall,'',CodeBlockID,0,SourceFile.SrcPos,CurrentID);
          if SourceFile.IsNext(ttPClose) then
            CurrentID:=ID
          else
           begin
            Push(pCall,ID,0,SourceFile.SrcPos);
            Push(pArgument,ID,0,SourceFile.SrcPos);
           end;
         end;
      ttComma:
       begin
        Resolve(p_List);
        if FStackIndex=0 then
          SourceFile.Error('Unexpected end of block')
        else
          case Top(ID,SrcPos) of
            pCall:Push(pArgument,ID,0,SrcPos);
            pSet:Push(pSetElem,ID,0,SrcPos);
            else SourceFile.Error('Unexpected ","');
          end;
       end;
      ttPClose:
        if Pop(pParentheses,ID) then
          //CurrentID:=CurrentID //assert ID=0
        else
          if Pop(pCall,ID) then
            CurrentID:=ID
          else
            SourceFile.Error('")" without according "("');

      rwIn:
        if CurrentID=0 then
          SourceFile.Error('"in" without left side')
        else
         begin
          Resolve(pOpIn);
          Push(pOpIn,CurrentID,0,SourceFile.SrcPos);
         end;
      ttBOpen:
       begin
        //if CurrentID<>0 then iNode(ntArrayIndex//TODO: array index!
        Push(pSet,d.iNode(ntSet,'',CodeBlockID,0,SourceFile.SrcPos),0,SourceFile.SrcPos)
       end;
      ttBClose:
        if Pop(pSet,ID) then
          CurrentID:=ID
        else
          SourceFile.Error('Unexpected "]"');
      ttRange:
        if CurrentID=0 then
          SourceFile.Error('Range declaration left side missing')
        else
         begin
          Resolve(pRange);
          Push(pRange,CurrentID,0,SourceFile.SrcPos);
         end;

      rwBegin:
       begin
        Expose(0);
        case Top(ID,SrcPos) of
          pIfThen:CodeBlockID:=d.iNode(ntBeginEnd,'then',ID,0,SourceFile.SrcPos);
          pIfElse:CodeBlockID:=d.iNode(ntBeginEnd,'else',ID,0,SourceFile.SrcPos);
          pWhileDo:CodeBlockID:=d.iNode(ntBeginEnd,'do',ID,0,SourceFile.SrcPos);
          //pRepeat?
          else
            CodeBlockID:=d.iNode(ntBeginEnd,'',CodeBlockID,0,SourceFile.SrcPos);
        end;
        Push(pCodeBlock,CodeBlockID,0,SourceFile.SrcPos);
       end;
      rwEnd:
       begin
        Resolve(pCodeBlock);
        if CurrentID<>0 then
         begin
          d.sNodeP(CurrentID,ID);
          CurrentID:=0;
         end;
        if not(Pop(pCodeBlock,ID)) then
          SourceFile.Error('"end" without according "begin"');
       end;

      rwIf:
       begin
        Expose(0);
        ID:=d.iNode(ntIf,'',CodeBlockID,0,SourceFile.SrcPos);
        Push(pIfWhen,ID,0,SourceFile.SrcPos);
       end;
      rwThen:
       begin
        if Pop(pIfWhen,ID) then
         begin
          if CurrentID=0 then
            SourceFile.Error('"if" without selection citerium')
          else
            d.sNode1(ID,CurrentID);
          Push(pIfThen,ID,0,SourceFile.SrcPos)
         end
        else
          SourceFile.Error('"then" without "if"');
       end;
      rwElse:
        if Pop(pIfThen,ID) then
         begin
          if CurrentID<>0 then
           begin
            d.sNode2(ID,CurrentID);
            CurrentID:=0;
           end;
          Push(pIfElse,ID,0,SourceFile.SrcPos);
         end
        else
          SourceFile.Error('"else" without "then"');

      rwCase:
       begin
        Expose(0);
        Push(pCase,d.iNode(ntCase,'',CodeBlockID,0,SourceFile.SrcPos),0,SourceFile.SrcPos);
       end;
      rwOf:
        if Pop(pCase,ID) then
         begin
          d.sNode1(ID,CurrentID);
          ParseCase(d,ID);
         end
        else
          SourceFile.Error('unexpected "of"');

      rwTry:
       begin
        Expose(0);
        ID:=d.iNode(ntTry,'',CodeBlockID,0,SourceFile.SrcPos);
        CodeBlockID:=d.iNode(ntBeginEnd,'try',ID,0,SourceFile.SrcPos);
        Push(pTry,ID,0,SourceFile.SrcPos);
        Push(pCodeBlock,CodeBlockID,0,SourceFile.SrcPos);
       end;
      rwFinally:
        if Pop(pTry,ID) then
         begin
          SrcPos:=SourceFile.SrcPos;
          ID:=d.iNode(ntTryFinally,'',ID,0,SrcPos);
          Push(pCodeBlock,d.iNode(ntBeginEnd,'finally',ID,0,SrcPos),0,SrcPos);
         end
        else
          SourceFile.Error('"finally" without "try"');
      rwExcept:
        if Pop(pTry,ID) then
         begin
          //if SourceFile.IsNext(ttOn) then //TODO
          //Push(pTryExceptOn? ttElse?

          SrcPos:=SourceFile.SrcPos;
          ID:=d.iNode(ntTryExcept,'',ID,0,SrcPos);
          Push(pCodeBlock,d.iNode(ntBeginEnd,'except',ID,0,SrcPos),0,SrcPos);
         end
        else
          SourceFile.Error('"except" without "try"');
      rwRaise:
       begin
        Expose(0);
        Push(pRaise,0,0,SourceFile.SrcPos);
       end;

      rwWhile:
       begin
        Expose(0);
        ID:=d.iNode(ntWhile,'',CodeBlockID,0,SourceFile.SrcPos);
        Push(pWhileEx,ID,0,SourceFile.SrcPos);
       end;
      rwDo:
       begin
        if Pop(pWhileEx,ID) then
         begin
          if CurrentID=0 then
            SourceFile.Error('"while" without predicate')
          else
            d.sNode1(ID,CurrentID);
          Push(pWhileDo,ID,0,SourceFile.SrcPos)
         end
        else
          SourceFile.Error('"do" without "while"');
       end;


      //TODO:
      //rwInitialization:;
      //rwFinalization:;

      else
        SourceFile.Error('Unexpected syntax ('+DParseTokenText[tt]+')');
    end;
   end;
end;

procedure ParseCase(d:TDParseData;SubjectID:TNodeIndex);
var
  SourceFile:TDParseSourceFile;
  EntryID,CurrentID,RangeStartID:TNodeIndex;
  EntrySrcPos:TSrcPos;

  procedure DoEntry;
  begin
    if EntryID=0 then
     begin
      EntryID:=d.iNode(ntCaseEntry,'',SubjectID,0,EntrySrcPos);
      if RangeStartID=0 then
        d.iNode1(ntCaseValue,'',EntryID,0,SourceFile.SrcPos,CurrentID)
      else
       begin
        d.iNode2(ntCaseRange,'',EntryID,0,SourceFile.SrcPos,RangeStartID,CurrentID);
        RangeStartID:=0;
       end;
     end;
  end;

  procedure Expose(ObjectID:TNodeIndex);
  begin
    if CurrentID<>0 then
      SourceFile.Error('Invalid case label syntax');
    CurrentID:=ObjectID;
  end;

var
  tt:TDParseTokenType;
begin
  //case expression done by ParseImperative
  SourceFile:=d.SourceFile;
  EntryID:=0;
  EntrySrcPos:=SourceFile.SrcPos;
  CurrentID:=0;
  RangeStartID:=0;
  while not SourceFile.IsNext(rwEnd) do
   begin
    tt:=SourceFile.Token;
    case tt of

      ttIdentifier:
        Expose(d.iLookup(SourceFile.GetID));

      ttIntegerLiteral,ttStringLiteral,ttFloatingPointLiteral:
        Expose(d.iNode(ntConstant,SourceFile.GetRaw,0,cardinal(tt),SourceFile.SrcPos));

      ttComma:
        if CurrentID=0 then
          SourceFile.Error('Invalid case label syntax')
        else
          DoEntry;
      ttRange:
        if CurrentID=0 then
          SourceFile.Error('Invalid case label syntax')
        else
         begin
          RangeStartID:=CurrentID;
          CurrentID:=0;
         end;
      ttColon:
       begin
        DoEntry;
        ParseImperative(d,EntryID,true,EntryID);
        EntryID:=0;
        CurrentID:=0;
       end;
      rwElse:
       begin
        if EntryID<>0 then SourceFile.Error('Unexpected case "else"');
        EntryID:=d.iNode(ntCaseEntry,'else',SubjectID,0,SourceFile.SrcPos);
       end;

      else SourceFile.Error('Unexpected case syntax');
    end;
   end;
  //SourceFile.Expect(ttSemiColon);//by caller!
end;

end.
