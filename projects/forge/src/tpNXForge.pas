(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tpNXForge;

{$mode delphi}{$H+}

interface

type
  TNXForgeOperationKind = (fokCommand, fokRender, fokCreateDirectory, fokWriteTextFile,
    fokCopyFile, fokCompareFiles, fokDeletePath, fokArchive, fokBuildIdentity,
    fokPackageSDKOptions, fokPackageSDKManifest, fokPackageBuildPrepare,
    fokPackageBundlePublish, fokCompareDirectories, fokVerifyBuildIdentity);

implementation

end.
