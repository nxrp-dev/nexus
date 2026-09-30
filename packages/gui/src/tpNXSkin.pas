unit tpNXSkin;

{$mode objfpc}{$H+}

interface

uses
  fpg_base;

type
  TNXSkinColorRole = (
    scrWindowBackground,
    scrInputBackground,
    scrDarkShadow,
    scrWidgetFrame,
    scrPrimaryText,
    scrSelection,
    scrSelectionText,
    scrScrollBar,
    scrGridLines,
    scrFocus,
    scrButtonTop,
    scrButtonBottom,
    scrButtonHoverTop,
    scrButtonHoverBottom,
    scrButtonPressedTop,
    scrButtonPressedBottom,
    scrDisabledText,
    scrMenuSeparator,
    scrButtonHighlight,
    scrButtonBorder,
    scrProgressTop,
    scrProgressBottom,
    scrProgressHighlight,
    scrProgressBorder,
    scrProgressTrack,
    scrCheckBackground,
    scrCheckBorder,
    scrCheckMark,
    scrCheckPressed,
    scrInactiveTab,
    scrTabBorder
  );

  TNXSkinColors = array[TNXSkinColorRole] of TfpgColor;

const
  cNXSkinColorNames: array[TNXSkinColorRole] of string = (
    'WindowBackground',
    'InputBackground',
    'DarkShadow',
    'WidgetFrame',
    'PrimaryText',
    'Selection',
    'SelectionText',
    'ScrollBar',
    'GridLines',
    'Focus',
    'ButtonTop',
    'ButtonBottom',
    'ButtonHoverTop',
    'ButtonHoverBottom',
    'ButtonPressedTop',
    'ButtonPressedBottom',
    'DisabledText',
    'MenuSeparator',
    'ButtonHighlight',
    'ButtonBorder',
    'ProgressTop',
    'ProgressBottom',
    'ProgressHighlight',
    'ProgressBorder',
    'ProgressTrack',
    'CheckBackground',
    'CheckBorder',
    'CheckMark',
    'CheckPressed',
    'InactiveTab',
    'TabBorder'
  );

  cNXSkinDefaultColors: TNXSkinColors = (
    $FF31363B,
    $FF232629,
    $FF1E1E1E,
    $FF54575B,
    $FFEFF0F1,
    $FF3DAEE9,
    $FFFFFFFF,
    $FF3E4349,
    $FF4A4E52,
    $FF3DAEE9,
    $FF444A50,
    $FF383E44,
    $FF4F5862,
    $FF434B55,
    $FF2A3035,
    $FF252B30,
    $FF72767B,
    $FF4A4E52,
    $FF505860,
    $FF5E6164,
    $FF3DAEE9,
    $FF2A8BC4,
    $FF5BBEF0,
    $FF1F7AAE,
    $FF3E4349,
    $FF232629,
    $FF5E6164,
    $FFEFF0F1,
    $FF2A3035,
    $FF272B30,
    $FF54575B
  );

implementation

end.
