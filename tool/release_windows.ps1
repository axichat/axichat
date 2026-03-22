<#
.SYNOPSIS
Builds Axichat Windows release artifacts.

.DESCRIPTION
Run this script on Windows. It always produces:
  - dist\axichat-windows.zip
  - dist\axichat-windows.zip.sha256

If Inno Setup (`iscc`) is installed, it also produces:
  - dist\axichat-windows-setup.exe
  - dist\axichat-windows-setup.exe.sha256

Use Shorebird by default. Pass any extra Flutter arguments after the named
parameters.
#>

param(
  [ValidateSet("shorebird", "flutter")]
  [string]$Builder = "shorebird",
  [string]$Flavor = "production",
  [string]$FlutterVersion = "3.41.4",
  [string]$OutputDir = "dist",
  [string]$Version = "",
  [string]$EmailPublicToken = "",
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($EmailPublicToken)) {
  if (-not [string]::IsNullOrWhiteSpace($env:AXICHAT_EMAIL_PUBLIC_TOKEN)) {
    $EmailPublicToken = $env:AXICHAT_EMAIL_PUBLIC_TOKEN
  } elseif (-not [string]::IsNullOrWhiteSpace($env:EMAIL_PUBLIC_TOKEN)) {
    $EmailPublicToken = $env:EMAIL_PUBLIC_TOKEN
  } else {
    $EmailPublicToken = "axichatpublictoken"
  }
}

& flutter pub get
& dart run build_runner build --delete-conflicting-outputs
& flutter config --enable-windows-desktop

$buildArgs = @("--dart-define=EMAIL_PUBLIC_TOKEN=$EmailPublicToken") + $FlutterArgs

if ($Builder -eq "shorebird") {
  $shorebirdArgs = @(
    "release",
    "windows",
    "--flavor",
    $Flavor,
    "--flutter-version=$FlutterVersion",
    "--"
  ) + $buildArgs
  & shorebird @shorebirdArgs
} else {
  $flutterBuildArgs = @(
    "build",
    "windows",
    "--release",
    "--flavor",
    $Flavor
  ) + $buildArgs
  & flutter @flutterBuildArgs
}

$releaseDir = Join-Path $repoRoot "build/windows/x64/runner/Release"
$absoluteOutputDir = Join-Path $repoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $absoluteOutputDir | Out-Null

foreach ($dll in @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")) {
  $source = Join-Path $env:SystemRoot "System32\$dll"
  if (Test-Path $source) {
    Copy-Item -Force -Path $source -Destination $releaseDir
  }
}

$zipPath = Join-Path $absoluteOutputDir "axichat-windows.zip"
if (Test-Path $zipPath) {
  Remove-Item -Force $zipPath
}
Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $zipPath

if ([string]::IsNullOrWhiteSpace($Version)) {
  $pubspecVersion = Select-String -Path (Join-Path $repoRoot "pubspec.yaml") -Pattern '^version:\s+(.+)$'
  if (-not $pubspecVersion) {
    throw "Unable to determine version from pubspec.yaml."
  }
  $Version = $pubspecVersion.Matches[0].Groups[1].Value.Split('+')[0].TrimStart('v')
} else {
  $Version = $Version.TrimStart('v')
}

$isccPath = $null
$isccCommand = Get-Command iscc -ErrorAction SilentlyContinue
if ($isccCommand) {
  $isccPath = $isccCommand.Source
}

if (-not $isccPath) {
  foreach ($candidate in @(
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
  )) {
    if ($candidate -and (Test-Path $candidate)) {
      $isccPath = $candidate
      break
    }
  }
}

if ($isccPath) {
  & $isccPath `
    "/DAppVersion=$Version" `
    "/DAppSourceDir=$releaseDir" `
    "/DAppOutputDir=$absoluteOutputDir" `
    "packaging/windows/axichat.iss"
} else {
  Write-Host "Skipping installer build because Inno Setup (iscc) is not installed. Install Inno Setup or use the default path C:\Program Files (x86)\Inno Setup 6\ISCC.exe to emit axichat-windows-setup.exe."
}

$checksumTargets = @($zipPath)
$installerPath = Join-Path $absoluteOutputDir "axichat-windows-setup.exe"
if (Test-Path $installerPath) {
  $checksumTargets += $installerPath
}

& (Join-Path $repoRoot "tool/write_sha256_files.ps1") @checksumTargets
