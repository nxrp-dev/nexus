unit tpNXRender;

{$mode objfpc}{$H+}

interface

type
  // Only departures from normal. An empty set is the normal state.
  TNXRenderState = (nrsDisabled, nrsPressed, nrsHovered, nrsFocused, nrsSelected);
  TNXRenderStates = set of TNXRenderState;

implementation

end.
