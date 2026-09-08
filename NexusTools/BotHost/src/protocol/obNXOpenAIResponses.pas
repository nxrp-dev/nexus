unit obNXOpenAIResponses;

{$mode objfpc}{$H+}

interface

uses
  fpjson,
  obNXJSONValues;

type
  TNXOpenAIInputContent = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
  published
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIInputText = class(TNXOpenAIInputContent)
  private
    Ftext: TNXJSONString;
  published
    property text: TNXJSONString read Ftext write Ftext;
  end;

  TNXOpenAIInputFile = class(TNXOpenAIInputContent)
  private
    Ffile_id: TNXJSONString;
  published
    property file_id: TNXJSONString read Ffile_id write Ffile_id;
  end;

  TNXOpenAIInputImage = class(TNXOpenAIInputContent)
  private
    Ffile_id: TNXJSONString;
  published
    property file_id: TNXJSONString read Ffile_id write Ffile_id;
  end;

  TNXOpenAIInputContentArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXOpenAIInputMessage = class(TNXJSONObject)
  private
    Fcontent: TNXOpenAIInputContentArray;
    Frole: TNXJSONString;
  published
    property content: TNXOpenAIInputContentArray read Fcontent write Fcontent;
    property role: TNXJSONString read Frole write Frole;
  end;

  TNXOpenAIInputMessageArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXOpenAIResponseRequest = class(TNXJSONObject)
  private
    Finput: TNXOpenAIInputMessageArray;
    Finstructions: TNXJSONString;
    Fmodel: TNXJSONString;
    Fprevious_response_id: TNXJSONString;
    Fstore: TNXJSONBoolean;
    Fstream: TNXJSONBoolean;
  published
    property input: TNXOpenAIInputMessageArray read Finput write Finput;
    property instructions: TNXJSONString read Finstructions write Finstructions;
    property model: TNXJSONString read Fmodel write Fmodel;
    property previous_response_id: TNXJSONString read Fprevious_response_id
      write Fprevious_response_id;
    property store: TNXJSONBoolean read Fstore write Fstore;
    property stream: TNXJSONBoolean read Fstream write Fstream;
  end;

  TNXOpenAIResponseError = class(TNXJSONObject)
  private
    Fcode: TNXJSONString;
    Fmessage: TNXJSONString;
    Fparam: TNXJSONString;
    Ftype: TNXJSONString;
  public
    constructor Create; override;
  published
    property code: TNXJSONString read Fcode write Fcode;
    property message: TNXJSONString read Fmessage write Fmessage;
    property param: TNXJSONString read Fparam write Fparam;
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIIncompleteDetails = class(TNXJSONObject)
  private
    Freason: TNXJSONString;
  published
    property reason: TNXJSONString read Freason write Freason;
  end;

  TNXOpenAIContentItem = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
  published
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIOutputText = class(TNXOpenAIContentItem)
  private
    Ftext: TNXJSONString;
  published
    property text: TNXJSONString read Ftext write Ftext;
  end;

  TNXOpenAIRefusal = class(TNXOpenAIContentItem)
  private
    Frefusal: TNXJSONString;
  published
    property refusal: TNXJSONString read Frefusal write Frefusal;
  end;

  TNXOpenAIContentArray = class(TNXJSONArray)
  protected
    function CreateItemForJSON(AData: TJSONData): TNXJSONValue; override;
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXOpenAIOutputItem = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
  published
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIOutputMessage = class(TNXOpenAIOutputItem)
  private
    Fcontent: TNXOpenAIContentArray;
    Fid: TNXJSONString;
    Frole: TNXJSONString;
    Fstatus: TNXJSONString;
  published
    property content: TNXOpenAIContentArray read Fcontent write Fcontent;
    property id: TNXJSONString read Fid write Fid;
    property role: TNXJSONString read Frole write Frole;
    property status: TNXJSONString read Fstatus write Fstatus;
  end;

  TNXOpenAIOutputArray = class(TNXJSONArray)
  protected
    function CreateItemForJSON(AData: TJSONData): TNXJSONValue; override;
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXOpenAIResponse = class(TNXJSONObject)
  private
    Ferror: TNXOpenAIResponseError;
    Fid: TNXJSONString;
    Fincomplete_details: TNXOpenAIIncompleteDetails;
    Foutput: TNXOpenAIOutputArray;
    Fstatus: TNXJSONString;
  public
    constructor Create; override;
    function ExtractCompletedText(out AText,
      ARefusal: UTF8String): Boolean;
  published
    property error: TNXOpenAIResponseError read Ferror write Ferror;
    property id: TNXJSONString read Fid write Fid;
    property incomplete_details: TNXOpenAIIncompleteDetails
      read Fincomplete_details write Fincomplete_details;
    property output: TNXOpenAIOutputArray read Foutput write Foutput;
    property status: TNXJSONString read Fstatus write Fstatus;
  end;

  TNXOpenAIErrorEnvelope = class(TNXJSONObject)
  private
    Ferror: TNXOpenAIResponseError;
  published
    property error: TNXOpenAIResponseError read Ferror write Ferror;
  end;

implementation

class function TNXOpenAIInputContentArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXOpenAIInputContent;
end;

class function TNXOpenAIInputMessageArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXOpenAIInputMessage;
end;

function JSONDiscriminator(AData: TJSONData): string;
var
  lType: TJSONData;
begin
  Result := '';
  if not (AData is TJSONObject) then
    Exit;
  lType := TJSONObject(AData).Find('type');
  if Assigned(lType) and (lType.JSONType = jtString) then
    Result := lType.AsString;
end;

constructor TNXOpenAIResponseError.Create;
begin
  inherited Create;
  code.AcceptsNull := True;
  param.AcceptsNull := True;
end;

class function TNXOpenAIContentArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXOpenAIContentItem;
end;

function TNXOpenAIContentArray.CreateItemForJSON(
  AData: TJSONData): TNXJSONValue;
var
  lClass: TNXJSONValueClass;
begin
  case JSONDiscriminator(AData) of
    'output_text': lClass := TNXOpenAIOutputText;
    'refusal': lClass := TNXOpenAIRefusal;
  else
    lClass := TNXOpenAIContentItem;
  end;
  Result := lClass.Create;
  Result.FromJSONData(AData);
end;

class function TNXOpenAIOutputArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXOpenAIOutputItem;
end;

function TNXOpenAIOutputArray.CreateItemForJSON(
  AData: TJSONData): TNXJSONValue;
var
  lClass: TNXJSONValueClass;
begin
  if JSONDiscriminator(AData) = 'message' then
    lClass := TNXOpenAIOutputMessage
  else
    lClass := TNXOpenAIOutputItem;
  Result := lClass.Create;
  Result.FromJSONData(AData);
end;

constructor TNXOpenAIResponse.Create;
begin
  inherited Create;
  error.AcceptsNull := True;
  incomplete_details.AcceptsNull := True;
end;

function TNXOpenAIResponse.ExtractCompletedText(out AText,
  ARefusal: UTF8String): Boolean;
var
  lContent: TNXJSONValue;
  lContentIndex: Integer;
  lItem: TNXJSONValue;
  lItemIndex: Integer;
  lMessage: TNXOpenAIOutputMessage;
begin
  AText := '';
  ARefusal := '';
  for lItemIndex := 0 to output.Count - 1 do
  begin
    lItem := output[lItemIndex];
    if not (lItem is TNXOpenAIOutputMessage) then
      Continue;
    lMessage := TNXOpenAIOutputMessage(lItem);
    if (lMessage.role.Value <> 'assistant') or
      (lMessage.status.Value <> 'completed') then
      Continue;
    for lContentIndex := 0 to lMessage.content.Count - 1 do
    begin
      lContent := lMessage.content[lContentIndex];
      if lContent is TNXOpenAIOutputText then
        AText := AText + TNXOpenAIOutputText(lContent).text.Value
      else if (ARefusal = '') and (lContent is TNXOpenAIRefusal) then
        ARefusal := TNXOpenAIRefusal(lContent).refusal.Value;
    end;
  end;
  Result := AText <> '';
end;

end.
