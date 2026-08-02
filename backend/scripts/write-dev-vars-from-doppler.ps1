# Writes gitignored backend/.dev.vars from Doppler (twiffel / prd).
# Flutter never sees the xAI key, only TWIFFEL_API_BASE -> this Worker.

$ErrorActionPreference = "Stop"
$out = Join-Path $PSScriptRoot "..\.dev.vars"
$xai = doppler secrets get XAI --project twiffel --config prd --plain
if (-not $xai) { throw "Doppler secret XAI was empty for twiffel/prd" }

@(
  "DOPPLER_PROJECT=twiffel"
  "DOPPLER_CONFIG=prd"
  "XAI=$xai"
  "TWIFFEL_XAI_MODEL=grok-3-mini"
) | Set-Content -Path $out -Encoding utf8

Write-Host "Wrote $out (gitignored). Worker will use Doppler-sourced XAI locally."
