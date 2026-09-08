unit obNXOpenAIFiles;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues;

type
  TNXOpenAIFileObject = class(TNXJSONObject)
  private
    Fbytes: TNXJSONInteger;
    Ffilename: TNXJSONString;
    Fid: TNXJSONString;
    Fpurpose: TNXJSONString;
    Fstatus: TNXJSONString;
  published
    property bytes: TNXJSONInteger read Fbytes write Fbytes;
    property filename: TNXJSONString read Ffilename write Ffilename;
    property id: TNXJSONString read Fid write Fid;
    property purpose: TNXJSONString read Fpurpose write Fpurpose;
    property status: TNXJSONString read Fstatus write Fstatus;
  end;

implementation

end.
