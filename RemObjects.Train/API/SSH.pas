﻿namespace RemObjects.Train.API;

interface

uses
  System.Collections.Generic,
  System.Linq,
  System.Text;

type
  [PluginRegistration()]
  SSHReg = public class(IPluginRegistration)
  private
    class var fKeys: List<Renci.SshNet.PrivateKeyFile> := new List<Renci.SshNet.PrivateKeyFile>;
  protected
  public
    method &Register(aServices: IApiRegistrationServices);
    [WrapAs('ssh.execute', SkipDryRun := true, SecretArguments := [2, 3])]
    class method SshExecute(aServices: IApiRegistrationServices; aConnectionString, aCMD, aUSername, aPassword: String): String;
    [WrapAs('ssh.loadKey', SkipDryRun := true)]
    class method SshLoadKey(aServices: IApiRegistrationServices;ec: RemObjects.Script.EcmaScript.ExecutionContext;  aFN, aPassword: String);

    [WrapAs('sftp.connect', SkipDryRun := true, SecretArguments := [2, 3])]
    class method SftpConnect(aServices: IApiRegistrationServices; aServer, aRootpath, aUsername, aPassword: String): Renci.SshNet.SftpClient;

    [WrapAs('sftp.close', SkipDryRun := true, wantSelf := true)]
    class method SftpClose(aServices: IApiRegistrationServices; aSelf: Renci.SshNet.SftpClient);
    [WrapAs('sftp.listFiles', SkipDryRun := true, wantSelf := true)]
    class method SftpListFiles(aServices: IApiRegistrationServices; aSelf: Renci.SshNet.SftpClient; aPath: String): array of String;
    [WrapAs('sftp.listFolders', SkipDryRun := true, wantSelf := true)]
    class method SftpListFolders(aServices: IApiRegistrationServices; aSelf: Renci.SshNet.SftpClient; aPath: String): array of String;
    [WrapAs('sftp.download', SkipDryRun := true, wantSelf := true)]
    class method SftpDownload(aServices: IApiRegistrationServices; ec: RemObjects.Script.EcmaScript.ExecutionContext; aSelf: Renci.SshNet.SftpClient; aRemote, aLocal: String);
    [WrapAs('sftp.upload', SkipDryRun := true, wantSelf := true)]
    class method SftpUpload(aServices: IApiRegistrationServices;ec: RemObjects.Script.EcmaScript.ExecutionContext;  aSelf: Renci.SshNet.SftpClient; aLocal, aRemote: String);
  end;

implementation

method SSHReg.&Register(aServices: IApiRegistrationServices);
begin
  aServices.RegisterValue('ssh', new RemObjects.Script.EcmaScript.EcmaScriptObject(aServices.Globals)
  .AddValue('execute', RemObjects.Train.MUtilities.SimpleFunction(aServices.Engine, typeOf(SSHReg), 'SshExecute'))
  .AddValue('loadKey', RemObjects.Train.MUtilities.SimpleFunction(aServices.Engine, typeOf(SSHReg), 'SshLoadKey')));

  var lProto := new RemObjects.Script.EcmaScript.EcmaScriptObject(aServices.Globals);
  lProto.AddValue('listFiles', RemObjects.Train.MUtilities.SimpleFunction(aServices.Engine, typeOf(SSHReg), 'SftpListFiles'));
  lProto.AddValue('listFolders', RemObjects.Train.MUtilities.SimpleFunction(aServices.Engine, typeOf(SSHReg), 'SftpListFolders'));
  lProto.AddValue('download', RemObjects.Train.MUtilities.SimpleFunction(aServices.Engine, typeOf(SSHReg), 'SftpUpload'));
  lProto.AddValue('upload', RemObjects.Train.MUtilities.SimpleFunction(aServices.Engine, typeOf(SSHReg), 'SftpDownload'));
  lProto.AddValue('close', RemObjects.Train.MUtilities.SimpleFunction(aServices.Engine, typeOf(SSHReg), 'SftpClose'));
  aServices.RegisterValue('sftp', new RemObjects.Script.EcmaScript.EcmaScriptObject(aServices.Globals)
  .AddValue('connect', RemObjects.Train.MUtilities.SimpleFunction(aServices.Engine, typeOf(SSHReg), 'SftpConnect', lProto)));
end;

class method SSHReg.SshExecute(aServices: IApiRegistrationServices; aConnectionString: String; aCMD: String; aUSername: String; aPassword: String): String;
begin
  using fs := if String.IsNullOrEmpty(aPassword) then new Renci.SshNet.SshClient(aConnectionString, 22, aUSername, fKeys.ToArray) else
  new Renci.SshNet.SshClient(aConnectionString, 22, aUSername, aPassword) do begin
    fs.Connect;
    using cmd := fs.CreateCommand(aCMD) do begin
      cmd.CommandTimeout := new TimeSpan(0,0, 60);
      exit cmd.Execute();
    end;
  end;
end;

class method SSHReg.SshLoadKey(aServices: IApiRegistrationServices; ec: RemObjects.Script.EcmaScript.ExecutionContext; aFN: String; aPassword: String);
begin
  fKeys.Add(new Renci.SshNet.PrivateKeyFile(aServices.ResolveWithBase(ec,aFN), aPassword));
end;

class method SSHReg.SftpConnect(aServices: IApiRegistrationServices; aServer, aRootpath, aUsername, aPassword: String): Renci.SshNet.SftpClient;
begin
  result := if String.IsNullOrEmpty(aPassword) then new Renci.SshNet.SftpClient(aServer, 22, aUsername, fKeys.ToArray) else
  new Renci.SshNet.SftpClient(aServer, 22, aUsername, aPassword) ;
  result.Connect();
  if not String.IsNullOrEmpty(aRootpath) then
    result.ChangeDirectory(aRootpath);
end;

class method SSHReg.SftpClose(aServices: IApiRegistrationServices; aSelf: Renci.SshNet.SftpClient);
begin
  aSelf.Dispose;
end;
class method SSHReg.SftpListFiles(aServices: IApiRegistrationServices; aSelf: Renci.SshNet.SftpClient; aPath: String): array of String;
begin
  exit aSelf.ListDirectory(aPath).Where(a->a.IsRegularFile).Select(a->a.Name).ToArray;
end;
class method SSHReg.SftpListFolders(aServices: IApiRegistrationServices; aSelf: Renci.SshNet.SftpClient; aPath: String): array of String;
begin
  exit aSelf.ListDirectory(aPath).Where(a->a.IsDirectory).Select(a->a.Name).ToArray;
end;

class method SSHReg.SftpDownload(aServices: IApiRegistrationServices; ec: RemObjects.Script.EcmaScript.ExecutionContext; aSelf: Renci.SshNet.SftpClient; aRemote, aLocal: String);
begin
  using sr := new System.IO.FileStream(aServices.ResolveWithBase(ec,aLocal), System.IO.FileMode.Create) do
    aSelf.DownloadFile(aRemote, sr);
end;

class method SSHReg.SftpUpload(aServices: IApiRegistrationServices; ec: RemObjects.Script.EcmaScript.ExecutionContext; aSelf: Renci.SshNet.SftpClient; aLocal, aRemote: String);
begin
  using sr := new System.IO.FileStream(aServices.ResolveWithBase(ec,aLocal), System.IO.FileMode.Open, System.IO.FileAccess.Read, System.IO.FileShare.Read) do
    aSelf.UploadFile(sr,aRemote);
end;


end.