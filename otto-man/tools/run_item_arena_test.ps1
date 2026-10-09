# Item arena testini (gerçek düşmanlarla) çalıştırır. Kullanım: powershell -File tools/run_item_arena_test.ps1 [-Godot "<godot_console.exe>"] [-TimeoutSec 600]
param(
    [string]$Godot = "C:\Users\darea\Godot\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe",
    [int]$TimeoutSec = 600
)
$proj = Split-Path -Parent $PSScriptRoot
$out = Join-Path $env:TEMP "item_arena_out.txt"
$err = Join-Path $env:TEMP "item_arena_err.txt"
foreach ($f in @($out, $err)) { if ([IO.File]::Exists($f)) { [IO.File]::Delete($f) } }
$p = Start-Process -FilePath $Godot -ArgumentList "--headless", "--path", "`"$proj`"", "--script", "res://tools/item_arena_test.gd" -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -NoNewWindow
if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    Stop-Process -Id $p.Id -Force
    Write-Output "ARENA HUNG (zaman asimi $TimeoutSec sn)"
}
Get-Content $out -Encoding UTF8 | Select-String "ARENA " | ForEach-Object { $_.Line }
Get-Content $err -ErrorAction SilentlyContinue | Select-String "item_arena_test|Invalid (call|access)|Parse Error" | ForEach-Object { $_.Line }
# Betik hataları (bilinen açılış gürültüsü hariç): hem stdout hem stderr
$scriptErrors = @(Get-Content $out, $err -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String "SCRIPT ERROR" | Where-Object { $_.Line -notmatch "get_children' on a null value" })
if ($scriptErrors.Count -gt 0) {
    Write-Output "ARENA SCRIPT ERRORS: $($scriptErrors.Count)"
    $scriptErrors | Select-Object -First 8 | ForEach-Object { Write-Output ("  " + $_.Line) }
}
