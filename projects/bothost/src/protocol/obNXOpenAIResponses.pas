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

  TNXOpenAIInputItem = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
  published
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIInputMessage = class(TNXOpenAIInputItem)
  private
    Fcontent: TNXOpenAIInputContentArray;
    Frole: TNXJSONString;
  published
    property content: TNXOpenAIInputContentArray read Fcontent write Fcontent;
    property role: TNXJSONString read Frole write Frole;
  end;

  TNXOpenAIInputMessageArray = class(TNXJSONArray)
  protected
    function CreateItemForJSON(AData: TJSONData): TNXJSONValue; override;
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXOpenAIStringArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXOpenAIShellEnvironment = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
  published
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIShellTool = class(TNXJSONObject)
  private
    Fenvironment: TNXOpenAIShellEnvironment;
    Ftype: TNXJSONString;
  published
    property environment: TNXOpenAIShellEnvironment read Fenvironment
      write Fenvironment;
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIToolArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXOpenAIShellOutcome = class(TNXJSONObject)
  private
    Fexit_code: TNXJSONInteger;
    Ftype: TNXJSONString;
  published
    property exit_code: TNXJSONInteger read Fexit_code write Fexit_code;
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIShellOutput = class(TNXJSONObject)
  private
    Foutcome: TNXOpenAIShellOutcome;
    Fstderr: TNXJSONString;
    Fstdout: TNXJSONString;
  published
    property outcome: TNXOpenAIShellOutcome read Foutcome write Foutcome;
    property stderr: TNXJSONString read Fstderr write Fstderr;
    property stdout: TNXJSONString read Fstdout write Fstdout;
  end;

  TNXOpenAIShellOutputArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXOpenAIShellCallOutput = class(TNXOpenAIInputItem)
  private
    Fcall_id: TNXJSONString;
    Fmax_output_length: TNXJSONInteger;
    Foutput: TNXOpenAIShellOutputArray;
  published
    property call_id: TNXJSONString read Fcall_id write Fcall_id;
    property max_output_length: TNXJSONInteger read Fmax_output_length
      write Fmax_output_length;
    property output: TNXOpenAIShellOutputArray read Foutput write Foutput;
  end;

  TNXOpenAIResponseRequest = class(TNXJSONObject)
  private
    Finput: TNXOpenAIInputMessageArray;
    Finstructions: TNXJSONString;
    Fmodel: TNXJSONString;
    Fprevious_response_id: TNXJSONString;
    Fstore: TNXJSONBoolean;
    Fstream: TNXJSONBoolean;
    Fparallel_tool_calls: TNXJSONBoolean;
    Ftools: TNXOpenAIToolArray;
  published
    property input: TNXOpenAIInputMessageArray read Finput write Finput;
    property instructions: TNXJSONString read Finstructions write Finstructions;
    property model: TNXJSONString read Fmodel write Fmodel;
    property previous_response_id: TNXJSONString read Fprevious_response_id
      write Fprevious_response_id;
    property store: TNXJSONBoolean read Fstore write Fstore;
    property stream: TNXJSONBoolean read Fstream write Fstream;
    property parallel_tool_calls: TNXJSONBoolean read Fparallel_tool_calls
      write Fparallel_tool_calls;
    property tools: TNXOpenAIToolArray read Ftools write Ftools;
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

  TNXOpenAIShellAction = class(TNXJSONObject)
  private
    Fcommands: TNXOpenAIStringArray;
    Fmax_output_length: TNXJSONInteger;
    Ftimeout_ms: TNXJSONInteger;
    Ftype: TNXJSONString;
  published
    property commands: TNXOpenAIStringArray read Fcommands write Fcommands;
    property max_output_length: TNXJSONInteger read Fmax_output_length
      write Fmax_output_length;
    property timeout_ms: TNXJSONInteger read Ftimeout_ms write Ftimeout_ms;
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXOpenAIShellCall = class(TNXOpenAIOutputItem)
  private
    Faction: TNXOpenAIShellAction;
    Fcall_id: TNXJSONString;
    Fid: TNXJSONString;
    Fstatus: TNXJSONString;
  published
    property action: TNXOpenAIShellAction read Faction write Faction;
    property call_id: TNXJSONString read Fcall_id write Fcall_id;
    property id: TNXJSONString read Fid write Fid;
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
  Result := TNXOpenAIInputItem;
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

function TNXOpenAIInputMessageArray.CreateItemForJSON(
  AData: TJSONData): TNXJSONValue;
var
  lClass: TNXJSONValueClass;
begin
  case JSONDiscriminator(AData) of
    'message': lClass := TNXOpenAIInputMessage;
    'shell_call_output': lClass := TNXOpenAIShellCallOutput;
  else
    lClass := TNXOpenAIInputItem;
  end;
  Result := lClass.Create;
  Result.FromJSONData(AData);
end;

class function TNXOpenAIStringArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXJSONString;
end;

class function TNXOpenAIToolArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXOpenAIShellTool;
end;

class function TNXOpenAIShellOutputArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXOpenAIShellOutput;
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
  case JSONDiscriminator(AData) of
    'message': lClass := TNXOpenAIOutputMessage;
    'shell_call': lClass := TNXOpenAIShellCall;
  else
    lClass := TNXOpenAIOutputItem;
  end;
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
