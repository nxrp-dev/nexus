unit tpNXWindow;
{$mode objfpc}{$H+}

interface

type
  TNXModalResult = (
    mrNone,
    mrOK,
    mrCancel,
    mrYes,
    mrNo,
    mrRetry,
    mrIgnore,
    mrAbort
  );

  TNXWindowBorderStyle = (
    wbsNone,
    wbsSingle,
    wbsDialog,
    wbsTool
  );

  TNXWindowCloseAction = (
    wcaHide,
    wcaDestroy
  );

implementation

end.
