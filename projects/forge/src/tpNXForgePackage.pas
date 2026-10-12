(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit tpNXForgePackage;

{$mode delphi}{$H+}

interface

type
  TNXForgePackageDependency = record
    Name: string;
    Build: string;
  end;
  TNXForgePackageDependencies = array of TNXForgePackageDependency;
  TNXForgePackageMetadata = record
    Name: string;
    SDK: string;
    Build: string;
    Requires: TNXForgePackageDependencies;
  end;

implementation
end.
