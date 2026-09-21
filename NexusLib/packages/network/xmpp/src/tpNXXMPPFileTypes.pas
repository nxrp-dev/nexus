unit tpNXXMPPFileTypes;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

const
  cNXXMPPFileSharingNamespace = 'urn:xmpp:sfs:0';
  cNXXMPPFileMetadataNamespace = 'urn:xmpp:file:metadata:0';
  cNXXMPPFileHashNamespace = 'urn:xmpp:hashes:2';
  cNXXMPPURLDataNamespace = 'http://jabber.org/protocol/url-data';
  cNXXMPPFileMaximumAttachments = 8;
  cNXXMPPFileMaximumSources = 4;
  cNXXMPPFileMaximumHashes = 4;
  cNXXMPPFileMaximumURLBytes = 4096;
  cNXXMPPFileMaximumDescriptionBytes = 4096;
  cNXXMPPFileMaximumNameBytes = 255;
  cNXXMPPFileMaximumMediaTypeBytes = 255;
  cNXXMPPFileMaximumShareIDBytes = 255;
  cNXXMPPFileMaximumMetadataBytes = 65536;

type
  TNXXMPPFileHash = record
    Algorithm: UTF8String;
    Value: UTF8String;
  end;
  TNXXMPPFileHashArray = array of TNXXMPPFileHash;

  TNXXMPPFileSource = record
    URL: UTF8String;
  end;
  TNXXMPPFileSourceArray = array of TNXXMPPFileSource;

  TNXXMPPFileShare = record
    ID: UTF8String;
    Disposition: UTF8String;
    Name: UTF8String;
    MediaType: UTF8String;
    Description: UTF8String;
    HasSize: Boolean;
    DeclaredSize: Int64;
    Hashes: TNXXMPPFileHashArray;
    Sources: TNXXMPPFileSourceArray;
  end;
  TNXXMPPFileShareArray = array of TNXXMPPFileShare;

  TNXXMPPHTTPHeader = record
    Name: UTF8String;
    Value: UTF8String;
  end;
  TNXXMPPHTTPHeaderArray = array of TNXXMPPHTTPHeader;

  TNXXMPPHTTPUploadService = record
    JID: UTF8String;
    HasMaximumSize: Boolean;
    MaximumSize: Int64;
  end;
  TNXXMPPHTTPUploadServiceArray = array of TNXXMPPHTTPUploadService;

  TNXXMPPHTTPUploadSlot = record
    PutURL: UTF8String;
    GetURL: UTF8String;
    Headers: TNXXMPPHTTPHeaderArray;
  end;

implementation

end.
