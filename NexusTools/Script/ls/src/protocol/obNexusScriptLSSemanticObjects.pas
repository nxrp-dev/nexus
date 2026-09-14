unit obNexusScriptLSSemanticObjects;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolParams;

type
  TNexusScriptLSNodeArray = class;
  TNexusScriptLSProvenanceArray = class;
  TNexusScriptLSDialectPropertyRuleArray = class;
  TNexusScriptLSDialectChildRuleArray = class;

  TNexusScriptLSProvenance = class(TNXJSONObject)
  private
    FSourceURI: TNXJSONString;
    FRange: TNXLSRange;
    FWinner: TNXJSONBoolean;
  published
    property sourceUri: TNXJSONString read FSourceURI write FSourceURI;
    property range: TNXLSRange read FRange write FRange;
    property winner: TNXJSONBoolean read FWinner write FWinner;
  end;

  TNexusScriptLSProvenanceArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNexusScriptLSNode = class(TNXJSONObject)
  private
    FID: TNXJSONString;
    FNodeType: TNXJSONString;
    FKind: TNXJSONString;
    FName: TNXJSONString;
    FValue: TNXJSONString;
    FRange: TNXLSRange;
    FSelectionRange: TNXLSRange;
    FChildren: TNexusScriptLSNodeArray;
    FSourceURI: TNXJSONString;
    FLocal: TNXJSONBoolean;
    FApplicable: TNXJSONBoolean;
    FOverrides: TNXJSONBoolean;
    FEffectiveValue: TNXJSONString;
    FEffectiveSourceURI: TNXJSONString;
    FEffectiveRange: TNXLSRange;
    FContributors: TNexusScriptLSProvenanceArray;
    FAllowedOperations: TNXJSONStringArray;
  published
    property id: TNXJSONString read FID write FID;
    property nodeType: TNXJSONString read FNodeType write FNodeType;
    property kind: TNXJSONString read FKind write FKind;
    property name: TNXJSONString read FName write FName;
    property value: TNXJSONString read FValue write FValue;
    property range: TNXLSRange read FRange write FRange;
    property selectionRange: TNXLSRange read FSelectionRange write FSelectionRange;
    property children: TNexusScriptLSNodeArray read FChildren write FChildren;
    property sourceUri: TNXJSONString read FSourceURI write FSourceURI;
    property local: TNXJSONBoolean read FLocal write FLocal;
    property applicable: TNXJSONBoolean read FApplicable write FApplicable;
    property overrides: TNXJSONBoolean read FOverrides write FOverrides;
    property effectiveValue: TNXJSONString read FEffectiveValue
      write FEffectiveValue;
    property effectiveSourceUri: TNXJSONString read FEffectiveSourceURI
      write FEffectiveSourceURI;
    property effectiveRange: TNXLSRange read FEffectiveRange
      write FEffectiveRange;
    property contributors: TNexusScriptLSProvenanceArray read FContributors
      write FContributors;
    property allowedOperations: TNXJSONStringArray read FAllowedOperations
      write FAllowedOperations;
  end;

  TNexusScriptLSNodeArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNexusScriptLSDocumentModel = class(TNXJSONObject)
  private
    FURI: TNXJSONString;
    FVersion: TNXJSONInteger;
    FRevision: TNXJSONInteger;
    FSucceeded: TNXJSONBoolean;
    FNodes: TNexusScriptLSNodeArray;
  published
    property uri: TNXJSONString read FURI write FURI;
    property version: TNXJSONInteger read FVersion write FVersion;
    property revision: TNXJSONInteger read FRevision write FRevision;
    property succeeded: TNXJSONBoolean read FSucceeded write FSucceeded;
    property nodes: TNexusScriptLSNodeArray read FNodes write FNodes;
  end;

  TNexusScriptLSDialectRule = class(TNXJSONObject)
  private
    FKind: TNXJSONString;
    FRoot: TNXJSONBoolean;
    FProperties: TNXJSONStringArray;
    FChildren: TNXJSONStringArray;
    FPropertyRules: TNexusScriptLSDialectPropertyRuleArray;
    FChildRules: TNexusScriptLSDialectChildRuleArray;
  published
    property kind: TNXJSONString read FKind write FKind;
    property root: TNXJSONBoolean read FRoot write FRoot;
    property properties: TNXJSONStringArray read FProperties write FProperties;
    property children: TNXJSONStringArray read FChildren write FChildren;
    property propertyRules: TNexusScriptLSDialectPropertyRuleArray
      read FPropertyRules write FPropertyRules;
    property childRules: TNexusScriptLSDialectChildRuleArray
      read FChildRules write FChildRules;
  end;

  TNexusScriptLSDialectPropertyRule = class(TNXJSONObject)
  private
    FName: TNXJSONString;
    FRequired: TNXJSONBoolean;
    FScalarKind: TNXJSONString;
    FAllowedValues: TNXJSONStringArray;
    FSourceForms: TNXJSONStringArray;
    FReferenceKinds: TNXJSONStringArray;
    FArrayValues: TNXJSONStringArray;
    FArrayDefinitionKinds: TNXJSONStringArray;
  published
    property name: TNXJSONString read FName write FName;
    property required: TNXJSONBoolean read FRequired write FRequired;
    property scalarKind: TNXJSONString read FScalarKind write FScalarKind;
    property allowedValues: TNXJSONStringArray read FAllowedValues write FAllowedValues;
    property sourceForms: TNXJSONStringArray read FSourceForms write FSourceForms;
    property referenceKinds: TNXJSONStringArray read FReferenceKinds write FReferenceKinds;
    property arrayValues: TNXJSONStringArray read FArrayValues write FArrayValues;
    property arrayDefinitionKinds: TNXJSONStringArray read FArrayDefinitionKinds
      write FArrayDefinitionKinds;
  end;

  TNexusScriptLSDialectChildRule = class(TNXJSONObject)
  private
    FName: TNXJSONString;
    FKinds: TNXJSONStringArray;
    FMinimum: TNXJSONInteger;
    FMaximum: TNXJSONInteger;
  published
    property name: TNXJSONString read FName write FName;
    property kinds: TNXJSONStringArray read FKinds write FKinds;
    property minimum: TNXJSONInteger read FMinimum write FMinimum;
    property maximum: TNXJSONInteger read FMaximum write FMaximum;
  end;

  TNexusScriptLSDialectPropertyRuleArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNexusScriptLSDialectChildRuleArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNexusScriptLSDialectRuleArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNexusScriptLSDialectModel = class(TNXJSONObject)
  private
    FRevision: TNXJSONInteger;
    FRules: TNexusScriptLSDialectRuleArray;
  published
    property revision: TNXJSONInteger read FRevision write FRevision;
    property rules: TNexusScriptLSDialectRuleArray read FRules write FRules;
  end;

  TNexusScriptLSTarget = class(TNXJSONObject)
  private
    FKind: TNXJSONString;
    FValue: TNXJSONString;
  published
    property kind: TNXJSONString read FKind write FKind;
    property value: TNXJSONString read FValue write FValue;
  end;

  TNexusScriptLSTargetArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNexusScriptLSSetTargetsParams = class(TNXJSONRPCObjectParams)
  private
    FTargets: TNexusScriptLSTargetArray;
  published
    property targets: TNexusScriptLSTargetArray read FTargets write FTargets;
  end;

  TNexusScriptLSSemanticEditParams = class(TNXJSONRPCObjectParams)
  private
    FTextDocument: TNXLSTextDocumentIdentifier;
    FVersion: TNXJSONInteger;
    FRevision: TNXJSONInteger;
    FNodeID: TNXJSONString;
    FOperation: TNXJSONString;
    FKind: TNXJSONString;
    FName: TNXJSONString;
    FValue: TNXJSONString;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FTextDocument
      write FTextDocument;
    property version: TNXJSONInteger read FVersion write FVersion;
    property revision: TNXJSONInteger read FRevision write FRevision;
    property nodeId: TNXJSONString read FNodeID write FNodeID;
    property operation: TNXJSONString read FOperation write FOperation;
    property kind: TNXJSONString read FKind write FKind;
    property name: TNXJSONString read FName write FName;
    property value: TNXJSONString read FValue write FValue;
  end;

implementation

class function TNexusScriptLSProvenanceArray.ItemClass:
  TNXJSONRPCValueClass;
begin
  Result := TNexusScriptLSProvenance;
end;

class function TNexusScriptLSNodeArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNexusScriptLSNode;
end;

class function TNexusScriptLSDialectRuleArray.ItemClass:
  TNXJSONRPCValueClass;
begin
  Result := TNexusScriptLSDialectRule;
end;

class function TNexusScriptLSTargetArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNexusScriptLSTarget;
end;

class function TNexusScriptLSDialectPropertyRuleArray.ItemClass:
  TNXJSONRPCValueClass;
begin
  Result := TNexusScriptLSDialectPropertyRule;
end;

class function TNexusScriptLSDialectChildRuleArray.ItemClass:
  TNXJSONRPCValueClass;
begin
  Result := TNexusScriptLSDialectChildRule;
end;

end.
