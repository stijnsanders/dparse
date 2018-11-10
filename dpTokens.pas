unit dpTokens;

interface

type
  TSrcPos=type cardinal;

  TDParseTokenType=(
    ttIdentifier,
    ttStringLiteral,
    ttIntegerLiteral,
    ttFloatingPointLiteral,

    tt_Fixed,//all below have fixed content

    ttSemiColon,//";"
    ttComma,//','
    ttPeriod, //"."
    ttRange, //".."
    ttColon,//":"
    ttAt,//"@"
    ttCaret,//"^"

    ttPOpen,ttPClose,//"()"
    //ttAOpen,ttAClose,//"<>"
    ttBOpen,ttBClose,//"[]"

    ttOpAssign, //":="
    ttOpEQ,
    ttOpNEQ,
    ttOpLT,
    ttOpLTE,
    ttOpGT,
    ttOpGTE,

    ttOpAdd,
    ttOpSub,
    ttOpMul,
    ttOpDiv,

    rw_ReservedWord,//reserved words below,
    //IMPORTANT: listed alphabetically here:

    rwAnd,
    rwArray,
    rwAs,
    //rwAsm,
    rwBegin,
    rwCase,
    rwClass,
    rwConst,
    rwConstructor,
    rwDefault,
    rwDestructor,
    rwDispInterface,
    rwDiv,
    rwDo,
    rwDownTo,
    rwElse,
    rwEnd,
    rwExcept,
    rwExit,
    rwExports,
    rwFile,
    rwFinalization,
    rwFinally,
    rwFor,
    rwFunction,
    rwIf,
    rwImplementation,
    rwIn,
    rwInherited,
    rwInitialization,
    rwInterface,
    rwIs,
    rwLibrary,
    rwMod,
    rwNil,
    rwNot,
    rwObject,
    rwOf,
    rwOr,
    rwOut,
    rwPacked,
    rwPrivate,
    rwProcedure,
    rwProgram,
    rwProperty,
    rwProtected,
    rwPublic,
    rwPublished,
    rwRaise,
    rwRecord,
    rwRepeat,
    rwResourceString,
    rwSet,
    rwShl,
    rwShr,
    rwString,
    rwThen,
    rwThreadVar,
    rwTo,
    rwTry,
    rwType,
    rwUnit,
    rwUntil,
    rwUses,
    rwVar,
    rwWhile,
    rwWith,
    rwXor,

    //tt_OutOfReservedWords: see below

    tt_Unknown
  );

  TDParseToken=record
    Token:TDParseTokenType;
    Index,Length:cardinal;
    SrcPos:TSrcPos;
  end;

  TDParseTokenList=array of TDParseToken;

function DParseTokenize(const Code: UTF8String; LineIndex: cardinal): TDParseTokenList;

const
  DParseTokenText:array[TDParseTokenType] of string=(
    '','','','','',
    ';',',','.','..',':','|','^',
    '(',')','[',']',
    ':=','=','<>','<','<=','>','>=',
    '+','-','*','/',

    //reserved words
    '',
    //IMPORTANT: listed alphabetically here, lowercase!
    'and','array','as','begin','case','class','const','constructor','default',
    'destructor','dispinterface','div','do','downto','else','end','except',
    'exit','exports','file','finalization','finally','for','function','if',
    'implementation','in','inherited','initialization','interface','is',
    'library','mod','nil','not','object','of','or','out','packed','private',
    'procedure','program','property','protected','public','published','raise',
    'record','repeat','resourcestring','set','shl','shr','string','then',
    'threadvar','to','try','type','unit','until','uses','var','while','with',
    'xor',

    ''//
  );

  tt_OutOfReservedWords=tt_Unknown;


procedure WriteError(const ErrorMessage:string);

implementation

uses SysUtils;

function DParseTokenize(const Code: UTF8String; LineIndex: cardinal): TDParseTokenList;
var
  CodeIndex,CodeLength:cardinal;
  rl,ri,ln,lx:cardinal;

  procedure Add(Len:cardinal;t:TDParseTokenType);
  begin
    if ri=rl then
     begin
      inc(rl,$1000);//grow
      SetLength(Result,rl);
     end;
    Result[ri].Token:=t;
    Result[ri].Index:=CodeIndex;
    Result[ri].Length:=Len;
    //TODO: count tab as 4 (or 8 or 2)?
    Result[ri].SrcPos:=ln*LineIndex+(CodeIndex-lx)+1;
    inc(ri);
    inc(CodeIndex,Len);
  end;

  function CodeNext(Fwd:cardinal):AnsiChar;
  begin
    if CodeIndex+Fwd<=CodeLength then
      Result:=Code[CodeIndex+Fwd]
    else
      Result:=#0;
  end;

  procedure incCodeIndexX; //inc(CodeIndex) detecting EOL's
  begin
    case Code[CodeIndex] of
      #13:
       begin
        inc(ln);
        if CodeNext(1)=#10 then inc(CodeIndex);
        lx:=CodeIndex+1;
       end;
      #10:
       begin
        inc(ln);
        lx:=CodeIndex+1;
       end;
    end;
    inc(CodeIndex);
  end;

  procedure SkipWhiteSpace;
  begin
    while (CodeIndex<=CodeLength) and (Code[CodeIndex]<=' ') do incCodeIndexX;
  end;

  procedure AddX(Len:cardinal;t:TDParseTokenType); //add, but detect EOL's
  var
    i,l:cardinal;
  begin
    i:=CodeIndex;
    l:=CodeIndex+Len;
    if l>CodeLength then l:=CodeLength;
    while CodeIndex<>l do incCodeIndexX;
    CodeIndex:=i;
    Add(Len,t);
  end;

var
  i:cardinal;
  c:Char;
  tt:TDParseTokenType;
begin
  CodeIndex:=1;
  CodeLength:=Length(Code);
  ri:=0;
  rl:=0;
  lx:=1;
  ln:=1;
  SkipWhiteSpace;
  while CodeIndex<=CodeLength do
   begin
    case Code[CodeIndex] of
      '/':
        case CodeNext(1) of
          '/'://comment to EOL
           begin
            inc(CodeIndex,2);
            while (CodeIndex<=CodeLength) and not(Code[CodeIndex] in [#10,#12,#13]) do inc(CodeIndex);
            //EOL itself: see ShipWhiteSpace below
           end;
          else
            Add(1,ttOpDiv);
        end;
      '(':
        case CodeNext(1) of
          '*'://comment block
           begin
            inc(CodeIndex,2);
            //TODO: nested comment blocks
            while (CodeIndex<CodeLength) and not((Code[CodeIndex]='*') and (Code[CodeIndex+1]=')')) do incCodeIndexX;
            inc(CodeIndex,2);
           end;
          else
            Add(1,ttPOpen);
        end;
      ')':Add(1,ttPClose);
      '{'://comment block
       begin
        inc(CodeIndex);
        //TODO: nested comment blocks
        while (CodeIndex<CodeLength) and (Code[CodeIndex]<>'}') do incCodeIndexX;
        inc(CodeIndex);
       end;
      '[':Add(1,ttBOpen);
      ']':Add(1,ttBClose);
      '''','#'://string
       begin
        i:=CodeIndex;
        while (i<=CodeLength) and (Code[i] in ['''','#']) do
          if Code[i]='''' then
           begin
            inc(i);
            while (i<=CodeLength) and not(Code[i] in ['''',#10,#12,#13]) do inc(i);
            if (i<=CodeLength) and (Code[i]='''') then inc(i);//else raise?
           end
          else //Code[i]='#'
           begin
            inc(i);
            if (i<=CodeLength) and (Code[i]='$') then
             begin
              inc(i);
              while (i<=CodeLength) and (Code[i] in ['0'..'9','A'..'F','a'..'f']) do inc(i);
             end
            else
              while (i<=CodeLength) and (Code[i] in ['0'..'9']) do inc(i);
           end;
        AddX(i-CodeIndex,ttStringLiteral);
       end;
      '$','0'..'9'://digits
       begin
        tt:=ttIntegerLiteral;
        i:=CodeIndex+1;
        while (i<=CodeLength) and (Code[i] in ['0'..'9']) do inc(i);
        if (i<=CodeLength) and (Code[i]='.') then
         begin
          tt:=ttFloatingPointLiteral;
          inc(i);
          while (i<=CodeLength) and (Code[i] in ['0'..'9']) do inc(i);
         end;
        Add(i-CodeIndex,tt);
       end;
      '+':Add(1,ttOpAdd);
      '-':Add(1,ttOpSub);
      '*':Add(1,ttOpMul);
      '@':Add(1,ttAt);
      '^':Add(1,ttCaret);
      '<':
        case CodeNext(1) of
          '>':Add(2,ttOpNEQ);
          '=':Add(2,ttOpLTE);
          //TODO: generics
          else Add(1,ttOpLT);
        end;
      '>':
        case CodeNext(1) of
          '=':Add(2,ttOpGTE);
          else Add(1,ttOpGT);
        end;
      '=':Add(1,ttOpEq);
      '.':
        case CodeNext(1) of
          '.':Add(2,ttRange);
          '0'..'9':
           begin
            i:=CodeIndex+1;
            while (i<=CodeLength) and (Code[i] in ['0'..'9']) do inc(i);
            Add(i-CodeIndex,ttFloatingPointLiteral);
           end;
          else Add(1,ttPeriod);
        end;
      ',':Add(1,ttComma);
      ';':Add(1,ttSemiColon);
      ':':
        case CodeNext(1) of
          '=':Add(2,ttOpAssign);
          else Add(1,ttColon);
        end;
      'A'..'Z','_','a'..'z':
       begin
        i:=0;
        while (CodeIndex+i<=CodeLength)
          and (Code[CodeIndex+i] in ['0'..'9','A'..'Z','_','a'..'z']) do inc(i);
        tt:=rw_ReservedWord;
        inc(tt);
        c:=Code[CodeIndex];
        if c in ['A'..'Z'] then inc(byte(c),$20);//lowercase
        while (tt<>tt_OutOfReservedWords)
          and (DParseTokenText[tt][1]<>c) do inc(tt);
        while (tt<>tt_OutOfReservedWords)
          and not((i=cardinal(Length(DParseTokenText[tt])))
            and (LowerCase(Copy(Code,CodeIndex,i))=DParseTokenText[tt]))
          do
         begin
          inc(tt);
          if (tt<>tt_OutOfReservedWords) and (DParseTokenText[tt][1]<>c) then
            tt:=tt_OutOfReservedWords;
         end;
        if tt=tt_OutOfReservedWords then
          Add(i,ttIdentifier)
        else
          Add(i,tt);
       end;
      else Add(1,tt_Unknown);//raise?
    end;
    SkipWhiteSpace;
   end;
  SetLength(Result,ri);
end;

procedure WriteError(const ErrorMessage:string);
begin
  WriteLn(ErrOutput,ErrorMessage);
end;

end.
