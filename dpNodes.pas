unit dpNodes;

interface

type
  TNodeIndex=type int64;
  TNodeType=type cardinal;//TODO: proper enumeration?

const
  //flags

  Declaration_Interface = $0;
  Declaration_Implementation = $2;
  Declaration_Forward = $4;

  Record_Packed = $100;

  CallConv_Register = $100;
  CallConv_Pascal   = $200;
  CallConv_CDecl    = $300;
  CallConv_StdCall  = $400;
  CallConv_SafeCall = $500;

  Hint_Platform   = $1000;
  Hint_Deprecated = $2000;
  Hint_Library    = $3000;
  //Hint_Experimental

  Visibility_Public    = $0;
  Visibility_Published = $1;
  Visibility_Protected = $2;
  Visibility_Private   = $3;

  ArgMod_Const = $10;
  ArgMod_Var   = $20;
  ArgMod_Out   = $30;

  Method_Reintroduce = $4;
  Method_Overload    = $8;

  Method_Virtual  = $10;
  Method_Dynamic  = $20;
  Method_Override = $30;
  Method_Abstract = $40;//combinable with virtual,dynamic



  //node types IDs
  nt_Unknown = 0;

  ntUnit = 1000;
  ntProgram = 1100;
  ntLibrary = 1101;
  //more?

  ntUses = 1001;

  ntType = 100;
  ntVar = 101;
  ntThreadVar = 102;
  ntConstant = 103;
  ntResourceString = 104;
  ntEnumeration = 105;
  ntEnumValue = 106;
  ntProcedure = 110;
  ntFunction = 111;
  ntArgument = 112;
  ntTypeString = 113;
  ntArray = 114;
  ntArrayDimension = 115;
  ntSet = 116; //[x,y,z]
  ntSetElem = 117;
  ntRecord = 120;
  ntObject = 121;
  ntClass = 122;
  ntInterface = 123;
  ntDispInterface = 124;

  ntInheritsImplements = 201;
  ntConstructor = 202;
  ntDestructor = 203;
  ntClassProcedure = 204;
  ntClassFunction = 205;

  ntExternal = 999;

  ntBeginEnd = 1;
  ntIf = 2;
  ntWhile = 3;
  ntRepeat = 4;
  ntCase = 5;
  ntCaseEntry = 6;
  ntCaseValue = 7;
  ntCaseRange = 8;
  ntMember = 10;
  ntAssignment = 11;
  ntBinaryOp = 12;
  ntUnaryOp = 13;
  ntCall = 20;
  ntCallInherited = 21;

  ntTry = 30;
  ntTryFinally = 31;
  ntTryExcept = 32;
  ntRaise = 33;

implementation

end.
