unit obNXTreeMapTestData;

{$mode objfpc}{$H+}

interface

uses
  obNXTreeMap;

procedure GenerateTestData(out AData: TTransactionArray);

implementation

procedure GenerateTestData(out AData: TTransactionArray);
const
  cTestCategories: array[0..4] of String = (
    'Food',
    'Transport',
    'Entertainment',
    'Utilities',
    'Shopping'
  );

  cTestSubcategories: array[0..9] of String = (
    'Groceries',
    'Fuel',
    'Restaurants',
    'Power',
    'Water',
    'Movies',
    'Tools',
    'Clothes',
    'Repairs',
    'Misc'
  );

var
  lIndex: Integer;
begin
  Randomize;
  SetLength(AData, 100);

  for lIndex := 0 to High(AData) do
  begin
    AData[lIndex].Category := cTestCategories[Random(Length(cTestCategories))];
    AData[lIndex].Subcategory := cTestSubcategories[Random(Length(cTestSubcategories))];
    AData[lIndex].Amount := (Random(9000) + 500) / 100;
  end;
end;

end.
