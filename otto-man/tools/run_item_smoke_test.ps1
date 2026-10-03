# Item duman testini çalıştırır; bilinen zararsız gürültüyü eler, gerçek hataları ve SMOKE sonucunu gösterir.
# Kullanım: powershell -File tools/run_item_smoke_test.ps1 [-Godot "<godot_console.exe yolu>"]
param(
    [string]$Godot = "C:\Users\darea\Godot\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
# cmd /c: stderr'i PowerShell ErrorRecord'a çevirmeden birleştirir.
$raw = cmd /c "`"$Godot`" --headless --path `"$proj`" --script res://tools/item_smoke_test.gd 2>&1"
$raw | Select-String "SMOKE|Toplam item|aşama|SCRIPT ERROR|Parse Error|Invalid access|Invalid call" |
    Select-String -NotMatch "turtle_stats|spearman_enemy_stats|EnemyStats|turtle_enemy|spearman_enemy"
