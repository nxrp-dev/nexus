unit obNXPersistTests;

{$mode objfpc}{$H+}

interface

procedure RunNXPersistTests;

implementation

uses
  Classes,
  SysUtils,
  obNXPersist;

type
  TXXPersistMood = (
    pmCalm,
    pmFocused,
    pmChaotic
  );

  TXXPersistFlag = (
    pfVisible,
    pfEnabled,
    pfChecked
  );

  TXXPersistFlags = set of TXXPersistFlag;

  TXXPersistChild = class(TNXPersistObject)
  private
    FCaption: string;
    FScore: Integer;
  public
    class function PersistAlias: string; override;
  published
    property Caption: string read FCaption write FCaption;
    property Score: Integer read FScore write FScore;
  end;

  TXXPersistAnimal = class(TNXPersistObject)
  private
    FLegs: Integer;
    FSpecies: string;
  public
    class function PersistAlias: string; override;
  published
    property Legs: Integer read FLegs write FLegs;
    property Species: string read FSpecies write FSpecies;
  end;

  TXXPersistCat = class(TXXPersistAnimal)
  private
    FLives: Integer;
  public
    class function PersistAlias: string; override;
  published
    property Lives: Integer read FLives write FLives;
  end;

  TXXPersistDog = class(TXXPersistAnimal)
  private
    FGood: Boolean;
  public
    class function PersistAlias: string; override;
  published
    property Good: Boolean read FGood write FGood;
  end;

  TXXPersistRoot = class(TNXPersistObject)
  private
    FAnimals: TNXPersistList;
    FChild: TXXPersistChild;
    FFavorite: TXXPersistAnimal;
    FFlags: TXXPersistFlags;
    FMood: TXXPersistMood;
    FNotes: TStringList;
    FPayload: TNXPersistBinary;
    FTitle: string;
    procedure SetFavorite(AValue: TXXPersistAnimal);
  public
    constructor Create; override;
    destructor Destroy; override;

    class function PersistAlias: string; override;
  published
    property Animals: TNXPersistList read FAnimals;
    property Child: TXXPersistChild read FChild;
    property Favorite: TXXPersistAnimal read FFavorite write SetFavorite;
    property Flags: TXXPersistFlags read FFlags write FFlags;
    property Mood: TXXPersistMood read FMood write FMood;
    property Notes: TStringList read FNotes;
    property Payload: TNXPersistBinary read FPayload;
    property Title: string read FTitle write FTitle;
  end;

procedure AssertEqual(const AMessage, AExpected, AActual: string);
begin
  if AExpected <> AActual then
    raise Exception.Create(AMessage + LineEnding +
      'Expected:' + LineEnding + AExpected + LineEnding +
      'Actual:' + LineEnding + AActual);
end;

procedure AssertTrue(const AMessage: string; AValue: Boolean);
begin
  if not AValue then
    raise Exception.Create(AMessage);
end;

procedure SaveTextFile(const AFileName, AText: string);
var
  lFolder: string;
  lFile: TStringList;
begin
  lFolder := ExtractFilePath(AFileName);
  if lFolder <> '' then
    ForceDirectories(lFolder);

  lFile := TStringList.Create;
  try
    lFile.Text := AText;
    lFile.SaveToFile(AFileName);
  finally
    lFile.Free;
  end;
end;

procedure LoadPayload(APayload: TNXPersistBinary);
const
  cPayload: array[0..7] of Byte = (0, 1, 2, 3, 4, 5, Ord('N'), Ord('X'));
var
  lStream: TMemoryStream;
begin
  lStream := TMemoryStream.Create;
  try
    lStream.WriteBuffer(cPayload[0], SizeOf(cPayload));
    lStream.Position := 0;
    APayload.LoadFromStream(lStream);
  finally
    lStream.Free;
  end;
end;

procedure AssertPayload(const AMessage: string; APayload: TNXPersistBinary);
const
  cPayload: array[0..7] of Byte = (0, 1, 2, 3, 4, 5, Ord('N'), Ord('X'));
var
  lBytes: array[0..7] of Byte;
  lStream: TMemoryStream;
begin
  FillChar(lBytes, SizeOf(lBytes), 0);
  lStream := TMemoryStream.Create;
  try
    APayload.SaveToStream(lStream);
    AssertTrue(AMessage + ' size mismatch', lStream.Size = SizeOf(cPayload));
    lStream.Position := 0;
    lStream.ReadBuffer(lBytes[0], SizeOf(lBytes));
    AssertTrue(AMessage + ' content mismatch',
      CompareMem(@lBytes[0], @cPayload[0], SizeOf(cPayload)));
  finally
    lStream.Free;
  end;
end;

function BuildRoot: TXXPersistRoot;
var
  lCat: TXXPersistCat;
  lDog: TXXPersistDog;
begin
  Result := TXXPersistRoot.Create;
  Result.Title := 'Persist Test';
  Result.Mood := pmFocused;
  Result.Flags := [pfVisible, pfEnabled];
  Result.Child.Caption := 'Nested child';
  Result.Child.Score := 42;
  Result.Notes.Add('first line');
  Result.Notes.Add('second line');
  LoadPayload(Result.Payload);

  lCat := TXXPersistCat.Create;
  lCat.Name := 'Milo';
  lCat.Species := 'Cat';
  lCat.Legs := 4;
  lCat.Lives := 9;
  Result.Animals.Add(lCat);

  lCat := TXXPersistCat.Create;
  lCat.Name := 'Favorite';
  lCat.Species := 'Cat';
  lCat.Legs := 4;
  lCat.Lives := 7;
  Result.Favorite := lCat;

  lDog := TXXPersistDog.Create;
  lDog.Name := 'Ada';
  lDog.Species := 'Dog';
  lDog.Legs := 4;
  lDog.Good := True;
  Result.Animals.Add(lDog);
end;

class function TXXPersistChild.PersistAlias: string;
begin
  Result := 'Child';
end;

class function TXXPersistAnimal.PersistAlias: string;
begin
  Result := 'Animal';
end;

class function TXXPersistCat.PersistAlias: string;
begin
  Result := 'Cat';
end;

class function TXXPersistDog.PersistAlias: string;
begin
  Result := 'Dog';
end;

constructor TXXPersistRoot.Create;
begin
  inherited Create;
  StoreReadOnlyProperties := True;
  FChild := TXXPersistChild.Create;
  FAnimals := TNXPersistList.Create;
  FAnimals.ItemClass := TXXPersistAnimal;
  FNotes := TStringList.Create;
  FPayload := TNXPersistBinary.Create;
end;

destructor TXXPersistRoot.Destroy;
begin
  FreeAndNil(FFavorite);
  FreeAndNil(FPayload);
  FreeAndNil(FNotes);
  FreeAndNil(FAnimals);
  FreeAndNil(FChild);
  inherited Destroy;
end;

class function TXXPersistRoot.PersistAlias: string;
begin
  Result := 'Root';
end;

procedure TXXPersistRoot.SetFavorite(AValue: TXXPersistAnimal);
begin
  if FFavorite = AValue then
    Exit;

  FreeAndNil(FFavorite);
  FFavorite := AValue;
end;

procedure RunNXPersistTests;
var
  lAnimal: TNXPersistObject;
  lClone: TNXPersistObject;
  lJSON: string;
  lRoundTripJSON: string;
  lLoaded: TNXPersistObject;
  lRoot: TXXPersistRoot;
begin
  TNXPersistObject.RegisterPersistClass(TXXPersistChild);
  TNXPersistObject.RegisterPersistClass(TXXPersistAnimal);
  TNXPersistObject.RegisterPersistClass(TXXPersistCat);
  TNXPersistObject.RegisterPersistClass(TXXPersistDog);
  TNXPersistObject.RegisterPersistClass(TXXPersistRoot);

  lRoot := BuildRoot;
  try
    lJSON := lRoot.JSON;
    AssertTrue('Favorite should stream out', Pos('"Favorite"', lJSON) > 0);
    AssertTrue('Favorite descendant data should stream out',
      Pos('"Lives" : 7', lJSON) > 0);
    SaveTextFile('test_output\nxpersist.json', lJSON);

    lLoaded := TNXPersistObject.CreateObjectFromJSON(lJSON);
    try
      AssertTrue('Loaded object should be TXXPersistRoot',
        lLoaded is TXXPersistRoot);
      lRoundTripJSON := lLoaded.JSON;
      AssertEqual('Round-trip JSON mismatch', lJSON, lRoundTripJSON);
      AssertTrue('Root equality failed', lRoot.Equals(TNXPersistObject(lLoaded)));

      lAnimal := TXXPersistRoot(lLoaded).Animals[0];
      AssertTrue('First animal should reconstruct as TXXPersistCat',
        lAnimal is TXXPersistCat);

      lAnimal := TXXPersistRoot(lLoaded).Animals[1];
      AssertTrue('Second animal should reconstruct as TXXPersistDog',
        lAnimal is TXXPersistDog);
      AssertTrue('Favorite should stream-construct as TXXPersistCat',
        TXXPersistRoot(lLoaded).Favorite is TXXPersistCat);
      AssertTrue('Favorite descendant value should round-trip',
        TXXPersistCat(TXXPersistRoot(lLoaded).Favorite).Lives = 7);
      AssertPayload('Loaded payload', TXXPersistRoot(lLoaded).Payload);
    finally
      lLoaded.Free;
    end;

    lClone := lRoot.CloneSelf;
    try
      AssertEqual('Clone JSON mismatch', lJSON, lClone.JSON);
    finally
      lClone.Free;
    end;
  finally
    lRoot.Free;
  end;
end;

initialization
  TNXPersistObject.RegisterPersistClass(TXXPersistChild);
  TNXPersistObject.RegisterPersistClass(TXXPersistAnimal);
  TNXPersistObject.RegisterPersistClass(TXXPersistCat);
  TNXPersistObject.RegisterPersistClass(TXXPersistDog);
  TNXPersistObject.RegisterPersistClass(TXXPersistRoot);

end.
