(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tpNXSetup;

{$mode delphi}{$H+}

interface

type
  TNXSetupChildMode = (scmIndependent, scmExclusive);
  TNXSetupPayloadKind = (spkFile, spkDirectory);
  TNXSetupAcquisitionKind = (sakNone, sakPayload, sakWeb);
  TNXSetupInstallerKind = (sikNone, sikExe, sikMSI, sikVSIX);
  TNXSetupOwnership = (soShared, soOwned);
  TNXSetupOperation = (sopInstall, sopRepair, sopUninstall);
  TNXSetupWizardPage = (swpWelcome, swpDestination, swpComponents, swpReady,
    swpInstalling, swpFinished);

  TNXSetupAcquisition = record
    Kind: TNXSetupAcquisitionKind;
    Source: string;
  end;

  TNXSetupInstaller = record
    Kind: TNXSetupInstallerKind;
  end;

implementation

end.
