unit tpNXTest;

{$mode objfpc}{$H+}

interface

const
  cNXTestSuccess = 0;
  cNXTestErrorNotInitialized = -1;
  cNXTestErrorInvalidRequest = -2;
  cNXTestErrorUnknownCommand = -3;
  cNXTestErrorUnknownTest = -4;
  cNXTestErrorBufferTooSmall = -5;
  cNXTestErrorInternal = -6;
  cNXTestErrorUnknownResult = -7;
  cNXTestErrorInvalidArgument = -8;

  cJsonRpcParseError = -32700;
  cJsonRpcInvalidRequest = -32600;
  cJsonRpcMethodNotFound = -32601;
  cJsonRpcInvalidParams = -32602;
  cJsonRpcInternalError = -32603;

  cNXTestStatusNotRun = 'notRun';
  cNXTestStatusPassed = 'passed';
  cNXTestStatusFailed = 'failed';
  cNXTestStatusError = 'error';
  cNXTestStatusSkipped = 'skipped';

  cNXTestMethodGetCapabilities = 'nxtest/getCapabilities';
  cNXTestMethodListTests = 'nxtest/listTests';
  cNXTestMethodRunTest = 'nxtest/runTest';
  cNXTestMethodRunSuite = 'nxtest/runSuite';
  cNXTestMethodRunAll = 'nxtest/runAll';

  cNXTestApiVersion = 1;

implementation

end.
