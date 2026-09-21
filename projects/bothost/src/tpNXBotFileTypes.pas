unit tpNXBotFileTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs;

type
  TNXBotFileOrigin = (bfoInboundXMPP, bfoProvider);

  TNXBotFileSendRequest = record
    ArtifactID: UTF8String;
    RoomDelivery: Boolean;
    RoomJID: UTF8String;
    SenderJID: UTF8String;
    ReplyID: UTF8String;
  end;

  TNXBotFileSendCompletion = procedure(ASuccess: Boolean;
    const ADetail: UTF8String) of object;

  TNXBotAttachment = class
  private
    FArtifactID: UTF8String;
    FDescription: UTF8String;
    FDisposition: UTF8String;
    FHashSHA256: UTF8String;
    FID: UTF8String;
    FMediaType: UTF8String;
    FName: UTF8String;
    FOrigin: TNXBotFileOrigin;
    FPath: string;
    FSFSID: UTF8String;
    FSize: Int64;
    FSourceURL: UTF8String;
  public
    function Clone: TNXBotAttachment;
    property ArtifactID: UTF8String read FArtifactID write FArtifactID;
    property Description: UTF8String read FDescription write FDescription;
    property Disposition: UTF8String read FDisposition write FDisposition;
    property HashSHA256: UTF8String read FHashSHA256 write FHashSHA256;
    property ID: UTF8String read FID write FID;
    property MediaType: UTF8String read FMediaType write FMediaType;
    property Name: UTF8String read FName write FName;
    property Origin: TNXBotFileOrigin read FOrigin write FOrigin;
    property Path: string read FPath write FPath;
    property SFSID: UTF8String read FSFSID write FSFSID;
    property Size: Int64 read FSize write FSize;
    property SourceURL: UTF8String read FSourceURL write FSourceURL;
  end;

  TNXBotAttachmentList = class
  private
    FItems: TObjectList;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TNXBotAttachment;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(AAttachment: TNXBotAttachment);
    function Remove(const AID: UTF8String): Boolean;
    function Clone: TNXBotAttachmentList;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TNXBotAttachment read GetItem; default;
  end;

function NXBotFileSendRequest(const AArtifactID: UTF8String;
  ARoomDelivery: Boolean; const ARoomJID,
  ASenderJID, AReplyID: UTF8String): TNXBotFileSendRequest;

implementation

function NXBotFileSendRequest(const AArtifactID: UTF8String;
  ARoomDelivery: Boolean; const ARoomJID,
  ASenderJID, AReplyID: UTF8String): TNXBotFileSendRequest;
begin
  Result.ArtifactID := AArtifactID;
  Result.RoomDelivery := ARoomDelivery;
  Result.RoomJID := ARoomJID;
  Result.SenderJID := ASenderJID;
  Result.ReplyID := AReplyID;
end;

function TNXBotAttachment.Clone: TNXBotAttachment;
begin
  Result := TNXBotAttachment.Create;
  Result.FArtifactID := FArtifactID;
  Result.FDescription := FDescription;
  Result.FDisposition := FDisposition;
  Result.FHashSHA256 := FHashSHA256;
  Result.FID := FID;
  Result.FMediaType := FMediaType;
  Result.FName := FName;
  Result.FOrigin := FOrigin;
  Result.FPath := FPath;
  Result.FSFSID := FSFSID;
  Result.FSize := FSize;
  Result.FSourceURL := FSourceURL;
end;

constructor TNXBotAttachmentList.Create;
begin
  inherited Create;
  FItems := TObjectList.Create(True);
end;

destructor TNXBotAttachmentList.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TNXBotAttachmentList.Add(AAttachment: TNXBotAttachment);
begin
  if not Assigned(AAttachment) then
    Exit;
  FItems.Add(AAttachment);
end;

function TNXBotAttachmentList.Remove(const AID: UTF8String): Boolean;
var
  lIndex: Integer;
begin
  for lIndex := FItems.Count - 1 downto 0 do
    if TNXBotAttachment(FItems[lIndex]).ID = AID then
    begin
      FItems.Delete(lIndex);
      Exit(True);
    end;
  Result := False;
end;

function TNXBotAttachmentList.Clone: TNXBotAttachmentList;
var
  lIndex: Integer;
begin
  Result := TNXBotAttachmentList.Create;
  for lIndex := 0 to Count - 1 do
    Result.Add(Items[lIndex].Clone);
end;

function TNXBotAttachmentList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TNXBotAttachmentList.GetItem(AIndex: Integer): TNXBotAttachment;
begin
  Result := TNXBotAttachment(FItems[AIndex]);
end;

end.
