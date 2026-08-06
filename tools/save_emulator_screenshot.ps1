# Save current emulator screen to screenshots/emulator/ (app must already be open).
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Device = "emulator-5554"
)

$Root = Split-Path $PSScriptRoot -Parent
$OutDir = Join-Path $Root "screenshots\emulator"
$Adb = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"
$Dest = Join-Path $OutDir $Name

if (-not $Name.EndsWith(".png")) { $Dest = "$Dest.png" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$si = New-Object System.Diagnostics.ProcessStartInfo
$si.FileName = $Adb
$si.Arguments = "-s $Device exec-out screencap -p"
$si.RedirectStandardOutput = $true
$si.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($si)
$fs = [System.IO.File]::Create($Dest)
$p.StandardOutput.BaseStream.CopyTo($fs)
$fs.Close()
$p.WaitForExit()

$kb = [math]::Round((Get-Item $Dest).Length / 1KB, 1)
Write-Host "Saved $Dest ($kb KB)"
