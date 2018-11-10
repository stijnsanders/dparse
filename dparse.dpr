program dparse;

uses
  SysUtils,
  Classes,
  SQLite in 'SQLite.pas',
  SQLiteData in 'SQLiteData.pas',
  DataLank in 'DataLank.pas',
  dpTokens in 'dpTokens.pas',
  dpNodes in 'dpNodes.pas',
  dpParse in 'dpParse.pas',
  dpSource in 'dpSource.pas',
  dpData in 'dpData.pas',
  dpConst in 'dpConst.pas';

{$APPTYPE CONSOLE}

{$R *.res}

var
  d:TDataConnection;
  s:TDParseSourceFile;
  fn:string;
begin
  try
    fn:='test.data';//TODO

    DeleteFile(fn);
    d:=TDataConnection.Create(fn);
    try
      d.BusyTimeout:=5000;//?
      DParseInitData(d);

      d.Execute('BEGIN TRANSACTION');
      try

        //

        s:=TDParseSourceFile.Create;
        try
          s.LoadFromFile('D:\Data\2018\strato\stratoTokenizer.pas');
          DParseSource(d,s);
        finally
          s.Free;
        end;


        d.Execute('COMMIT TRANSACTION');
      except
        d.Execute('ROLLBACK TRANSACTION');
        raise;
      end;

    finally
      d.Free;
    end;

  except
    on e:Exception do
     begin
      writeln('### Abnormal termination: '+e.Message);
      exitcode:=1;
     end;
  end;
end.
