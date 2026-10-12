<#
.SYNOPSIS
  Pushes a Windows export of Rogue Harem to itch.io with butler and writes a devlog draft.

.DESCRIPTION
  1. Reads the game version from project.godot (config/version) and checks export_presets.cfg
     carries the same number.
  2. Builds docs/devlog/<version>.md from the matching section of CHANGELOG.md. itch.io has no
     API for posting devlogs, so you paste this file into a new devlog by hand.
  3. Checks the export folder (exe, license file, no model file, product name).
  4. Runs `butler push` with the version number from project.godot.

  Nothing is uploaded unless you pass -Push. Without it the script prints the butler command.

.EXAMPLE
  # only write the devlog draft
  powershell -File tools\push_itch.ps1 -DevlogOnly

  # check an export and show what would be pushed
  powershell -File tools\push_itch.ps1 -BuildDir "D:\otto_exp"

  # really upload
  powershell -File tools\push_itch.ps1 -BuildDir "D:\otto_exp" -Push

.NOTES
  Keep this file ASCII only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
#>
param(
	[string]$BuildDir = "",
	[string]$Target = "gnsu/rogue-harem",
	[string]$Channel = "windows",
	[string]$ExeName = "otto-man.exe",
	[string]$ButlerPath = "",
	[switch]$Push,
	[switch]$DevlogOnly
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Fail([string]$msg) {
	Write-Host "ERROR: $msg" -ForegroundColor Red
	exit 1
}

# --- 1. version --------------------------------------------------------------------------
$projectFile = Join-Path $ProjectDir "project.godot"
$projectText = [System.IO.File]::ReadAllText($projectFile, $Utf8NoBom)
$m = [regex]::Match($projectText, 'config/version="([^"]+)"')
if (-not $m.Success) { Fail "config/version not found in project.godot" }
$version = $m.Groups[1].Value
Write-Host "Game version: $version"

$presetsFile = Join-Path $ProjectDir "export_presets.cfg"
$presetsText = [System.IO.File]::ReadAllText($presetsFile, $Utf8NoBom)
foreach ($key in @("file_version", "product_version")) {
	$pm = [regex]::Match($presetsText, "application/$key=`"([^`"]+)`"")
	if (-not $pm.Success) { Fail "application/$key not found in export_presets.cfg" }
	if ($pm.Groups[1].Value -ne "$version.0") {
		Fail "export_presets.cfg application/$key is $($pm.Groups[1].Value), expected $version.0 (bump both files together)"
	}
}

# --- 2. devlog draft ---------------------------------------------------------------------
$changelogFile = Join-Path $ProjectDir "CHANGELOG.md"
if (-not (Test-Path -LiteralPath $changelogFile)) { Fail "CHANGELOG.md not found" }
$changelog = [System.IO.File]::ReadAllText($changelogFile, $Utf8NoBom)
$sectionRx = "(?ms)^##\s+" + [regex]::Escape($version) + "\b[^\r\n]*\r?\n(.*?)(?=^##\s|\z)"
$sec = [regex]::Match($changelog, $sectionRx)
if (-not $sec.Success) { Fail "CHANGELOG.md has no '## $version' section. Add the notes first." }
$body = $sec.Groups[1].Value

function Get-Part([string]$text, [string]$lang) {
	$rx = "(?ms)^###\s+" + $lang + "\s*\r?\n(.*?)(?=^###\s|\z)"
	$pm = [regex]::Match($text, $rx)
	if (-not $pm.Success) { return "" }
	return $pm.Groups[1].Value.Trim()
}
$tr = Get-Part $body "TR"
$en = Get-Part $body "EN"
if ([string]::IsNullOrWhiteSpace($tr) -or [string]::IsNullOrWhiteSpace($en)) {
	Fail "Section $version needs both '### TR' and '### EN' lists"
}

$turkish = "T" + [char]0x00FC + "rk" + [char]0x00E7 + "e"
$devlogDir = Join-Path $ProjectDir "docs\devlog"
New-Item -ItemType Directory -Force -Path $devlogDir | Out-Null
$devlogFile = Join-Path $devlogDir "$version.md"
$devlog = "# Rogue Harem $version`r`n`r`n## $turkish`r`n`r`n$tr`r`n`r`n## English`r`n`r`n$en`r`n"
[System.IO.File]::WriteAllText($devlogFile, $devlog, $Utf8NoBom)
Write-Host "Devlog draft written: $devlogFile"

if ($DevlogOnly) { exit 0 }

# --- 3. export folder checks -------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($BuildDir)) { Fail "Pass -BuildDir <export folder> (or use -DevlogOnly)" }
if (-not (Test-Path -LiteralPath $BuildDir -PathType Container)) { Fail "BuildDir not found: $BuildDir" }
$exe = Join-Path $BuildDir $ExeName
if (-not (Test-Path -LiteralPath $exe)) { Fail "$ExeName not found in $BuildDir (a missing-folder export can 'succeed' with nothing written)" }
if (-not (Test-Path -LiteralPath (Join-Path $BuildDir "THIRD_PARTY_LICENSES.txt"))) {
	Fail "THIRD_PARTY_LICENSES.txt must sit next to the exe (manual step after every export)"
}
$models = Get-ChildItem -LiteralPath $BuildDir -Recurse -Filter "*.gguf" -ErrorAction SilentlyContinue
if ($models) { Fail "Model file found in the export ($($models[0].FullName)). It must not ship, it lives in user://models" }
$info = (Get-Item -LiteralPath $exe).VersionInfo
if ($info.ProductName -ne "Rogue Harem") {
	Fail "exe ProductName is '$($info.ProductName)', expected 'Rogue Harem' (rcedit did not run)"
}
if ($info.FileVersion -ne "$version.0") {
	Write-Host "WARNING: exe FileVersion is $($info.FileVersion), expected $version.0 (export may be older than project.godot)" -ForegroundColor Yellow
}
$sizeMb = [math]::Round(((Get-ChildItem -LiteralPath $BuildDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB)
Write-Host "Export folder OK: $sizeMb MB"

# --- 4. butler ---------------------------------------------------------------------------
$butler = $ButlerPath
if ([string]::IsNullOrWhiteSpace($butler)) {
	$cmd = Get-Command butler -ErrorAction SilentlyContinue
	if ($cmd) { $butler = $cmd.Source }
}
if ([string]::IsNullOrWhiteSpace($butler) -or -not (Test-Path -LiteralPath $butler)) {
	Fail "butler not found. Install it (https://itch.io/docs/butler/) and put it on PATH, or pass -ButlerPath"
}

$versionFile = Join-Path ([System.IO.Path]::GetTempPath()) "rogue_harem_itch_version.txt"
[System.IO.File]::WriteAllText($versionFile, $version, $Utf8NoBom)
$dest = "${Target}:${Channel}"
$butlerArgs = @("push", $BuildDir, $dest, "--userversion-file", $versionFile)

Write-Host ""
Write-Host "butler command: $butler $($butlerArgs -join ' ')"
if (-not $Push) {
	Write-Host "Dry run. Add -Push to upload." -ForegroundColor Yellow
	exit 0
}

& $butler @butlerArgs
if ($LASTEXITCODE -ne 0) { Fail "butler push failed with exit code $LASTEXITCODE" }
Write-Host ""
Write-Host "Pushed $version to $dest." -ForegroundColor Green
Write-Host "Now open https://itch.io/dashboard and post the devlog from: $devlogFile"
