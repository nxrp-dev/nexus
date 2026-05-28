param(
  [Parameter(Position = 0)]
  [string]$Message = "Codex needs your attention.",

  [string]$Voice = "Microsoft David Desktop",

  [switch]$NoSpeech,
  [switch]$Beep
)

$ErrorActionPreference = "Stop"

function Invoke-FallbackBeep {
  try {
    [console]::beep(880, 250)
    Start-Sleep -Milliseconds 80
    [console]::beep(1175, 250)
  } catch {
    # Some hosts do not expose a console beep. Notification is best-effort.
  }
}

if ($NoSpeech -or $Beep) {
  Invoke-FallbackBeep
  exit 0
}

try {
  Add-Type -AssemblyName System.Speech
  $speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
  try {
    if ($Voice -ne "") {
      $speaker.SelectVoice($Voice)
    }
    $speaker.Speak($Message)
  } finally {
    $speaker.Dispose()
  }
} catch {
  Invoke-FallbackBeep
}
