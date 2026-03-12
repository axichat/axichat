param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]]$Files
)

$ErrorActionPreference = "Stop"

foreach ($file in $Files) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Missing file for checksum generation: $file"
  }

  $checksum = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant()
  $checksumPath = "$file.sha256"
  $fileName = Split-Path -Leaf $file
  "$checksum  $fileName" | Set-Content -LiteralPath $checksumPath -NoNewline:$false
  Write-Host "Wrote $checksumPath"
}
