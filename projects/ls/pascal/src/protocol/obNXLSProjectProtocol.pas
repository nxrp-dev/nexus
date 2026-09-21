unit obNXLSProjectProtocol;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXJSONRPCObjects;

type
  TNXLSProjectCreateWizardParams = class(TNXJSONRPCObjectParams)
  private
    FbuildTool: TNXJSONString;
    FworkspaceRoot: TNXJSONString;
    Fkind: TNXJSONString;
    FlpiFile: TNXJSONString;
  published
    property buildTool: TNXJSONString read FbuildTool write FbuildTool;
    property workspaceRoot: TNXJSONString read FworkspaceRoot write FworkspaceRoot;
    property kind: TNXJSONString read Fkind write Fkind;
    property lpiFile: TNXJSONString read FlpiFile write FlpiFile;
  end;

  TNXLSProjectCreateParams = class(TNXJSONRPCObjectParams)
  private
    FbuildTool: TNXJSONString;
    FprojectName: TNXJSONString;
    FtargetDir: TNXJSONString;
    Fkind: TNXJSONString;
    FlpiFile: TNXJSONString;
  published
    property buildTool: TNXJSONString read FbuildTool write FbuildTool;
    property projectName: TNXJSONString read FprojectName write FprojectName;
    property targetDir: TNXJSONString read FtargetDir write FtargetDir;
    property kind: TNXJSONString read Fkind write Fkind;
    property lpiFile: TNXJSONString read FlpiFile write FlpiFile;
  end;

  TNXLSProjectFieldOption = class(TNXJSONObject)
  private
    Fvalue: TNXJSONString;
    Flabel: TNXJSONString;
  published
    property value: TNXJSONString read Fvalue write Fvalue;
    property &label: TNXJSONString read Flabel write Flabel;
  end;

  TNXLSProjectFieldOptionArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectFieldSuggestion = class(TNXJSONObject)
  private
    Fkind: TNXJSONString;
    Flabel: TNXJSONString;
    Freason: TNXJSONString;
    Fvalue: TNXJSONString;
  published
    property kind: TNXJSONString read Fkind write Fkind;
    property &label: TNXJSONString read Flabel write Flabel;
    property reason: TNXJSONString read Freason write Freason;
    property value: TNXJSONString read Fvalue write Fvalue;
  end;

  TNXLSProjectFieldSuggestionArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectField = class(TNXJSONObject)
  private
    FbrowseLabel: TNXJSONString;
    Fdescription: TNXJSONString;
    Fid: TNXJSONString;
    Flabel: TNXJSONString;
    Fmessage: TNXJSONString;
    Foptions: TNXLSProjectFieldOptionArray;
    Frequired: TNXJSONBoolean;
    Fseverity: TNXJSONString;
    Fsuggestions: TNXLSProjectFieldSuggestionArray;
    Ftype: TNXJSONString;
    Fvalid: TNXJSONBoolean;
    Fvalue: TNXJSONString;
  published
    property browseLabel: TNXJSONString read FbrowseLabel write FbrowseLabel;
    property description: TNXJSONString read Fdescription write Fdescription;
    property id: TNXJSONString read Fid write Fid;
    property &label: TNXJSONString read Flabel write Flabel;
    property message: TNXJSONString read Fmessage write Fmessage;
    property options: TNXLSProjectFieldOptionArray read Foptions write Foptions;
    property required: TNXJSONBoolean read Frequired write Frequired;
    property severity: TNXJSONString read Fseverity write Fseverity;
    property suggestions: TNXLSProjectFieldSuggestionArray read Fsuggestions write Fsuggestions;
    property &type: TNXJSONString read Ftype write Ftype;
    property valid: TNXJSONBoolean read Fvalid write Fvalid;
    property value: TNXJSONString read Fvalue write Fvalue;
  end;

  TNXLSProjectFieldArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectRequestValue = class(TNXJSONObject)
  private
    FbuildTool: TNXJSONString;
    FprojectName: TNXJSONString;
    FtargetDir: TNXJSONString;
    Fkind: TNXJSONString;
    FlpiFile: TNXJSONString;
  published
    property buildTool: TNXJSONString read FbuildTool write FbuildTool;
    property projectName: TNXJSONString read FprojectName write FprojectName;
    property targetDir: TNXJSONString read FtargetDir write FtargetDir;
    property kind: TNXJSONString read Fkind write Fkind;
    property lpiFile: TNXJSONString read FlpiFile write FlpiFile;
  end;

  TNXLSProjectMessage = class(TNXJSONObject)
  private
    Fseverity: TNXJSONString;
    Ftext: TNXJSONString;
  published
    property severity: TNXJSONString read Fseverity write Fseverity;
    property text: TNXJSONString read Ftext write Ftext;
  end;

  TNXLSProjectMessageArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectOutput = class(TNXJSONObject)
  private
    Flabel: TNXJSONString;
    Fpath: TNXJSONString;
  published
    property &label: TNXJSONString read Flabel write Flabel;
    property path: TNXJSONString read Fpath write Fpath;
  end;

  TNXLSProjectOutputArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectDetail = class(TNXJSONObject)
  private
    Flabel: TNXJSONString;
    Fvalue: TNXJSONString;
  published
    property &label: TNXJSONString read Flabel write Flabel;
    property value: TNXJSONString read Fvalue write Fvalue;
  end;

  TNXLSProjectDetailArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectFile = class(TNXJSONObject)
  private
    Fpath: TNXJSONString;
    Fcontent: TNXJSONString;
  published
    property path: TNXJSONString read Fpath write Fpath;
    property content: TNXJSONString read Fcontent write Fcontent;
  end;

  TNXLSProjectFileArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectCreateWizardResult = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
    Frequest: TNXLSProjectRequestValue;
    Ffields: TNXLSProjectFieldArray;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
    property request: TNXLSProjectRequestValue read Frequest write Frequest;
    property fields: TNXLSProjectFieldArray read Ffields write Ffields;
  end;

  TNXLSProjectPlanCreateResult = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
    Fsummary: TNXJSONString;
    FcanExecute: TNXJSONBoolean;
    Fmessages: TNXLSProjectMessageArray;
    Foutputs: TNXLSProjectOutputArray;
    Fdetails: TNXLSProjectDetailArray;
    Ffields: TNXLSProjectFieldArray;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
    property summary: TNXJSONString read Fsummary write Fsummary;
    property canExecute: TNXJSONBoolean read FcanExecute write FcanExecute;
    property messages: TNXLSProjectMessageArray read Fmessages write Fmessages;
    property outputs: TNXLSProjectOutputArray read Foutputs write Foutputs;
    property details: TNXLSProjectDetailArray read Fdetails write Fdetails;
    property fields: TNXLSProjectFieldArray read Ffields write Ffields;
  end;

  TNXLSProjectCreateResult = class(TNXJSONObject)
  private
    Fmessage: TNXJSONString;
    Ffiles: TNXLSProjectFileArray;
  published
    property message: TNXJSONString read Fmessage write Fmessage;
    property files: TNXLSProjectFileArray read Ffiles write Ffiles;
  end;

implementation

class function TNXLSProjectFieldArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectField;
end;

class function TNXLSProjectFieldOptionArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectFieldOption;
end;

class function TNXLSProjectFieldSuggestionArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectFieldSuggestion;
end;

class function TNXLSProjectMessageArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectMessage;
end;

class function TNXLSProjectOutputArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectOutput;
end;

class function TNXLSProjectDetailArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectDetail;
end;

class function TNXLSProjectFileArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectFile;
end;

end.

