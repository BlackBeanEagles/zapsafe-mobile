# Capture one screenshot via flutter run (full dart compile, no prebuilt binary).
param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Route,
    [string]$ExtraDefine = "",
    [string]$Device = "emulator-5554",
    [int]$WaitSec = 200
)

$Root = Split-Path $PSScriptRoot -Parent
$OutDir = Join-Path $Root "screenshots\emulator"
$Adb = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"
$Flutter = "C:\flutter\bin\flutter.bat"
$Pkg = "com.zapsafe.zapsafe_mobile"
$Dest = Join-Path $OutDir $Name
$Log = Join-Path $OutDir "_single_run.log"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Set-Location $Root

Get-Process -Name "dart","java" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
& $Adb -s $Device shell am force-stop $Pkg 2>$null | Out-Null
Start-Sleep 5
if (Test-Path $Log) { Remove-Item $Log -Force }

$args = @("run", "-d", $Device, "--dart-define=INITIAL_ROUTE=$Route")
if ($ExtraDefine) { $args += "--dart-define=$ExtraDefine" }
Write-Host "flutter $($args -join ' ')"

$proc = Start-Process -FilePath $Flutter -ArgumentList $args `
    -WorkingDirectory $Root -PassThru -NoNewWindow -RedirectStandardOutput $Log

$deadline = (Get-Date).AddSeconds($WaitSec)
$ready = $false
while ((Get-Date) -lt $deadline -and -not $proc.HasExited) {
    if (Test-Path $Log) {
        $t = Get-Content $Log -Raw -ErrorAction SilentlyContinue
        if ($t -match "Flutter run key commands") { $ready = $true; break }
    }
    Start-Sleep 4
}

if ($ready) { Start-Sleep 18 } else { Start-Sleep 10 }

if (Test-Path $Dest) { Remove-Item $Dest -Force }
$si = New-Object System.Diagnostics.ProcessStartInfo
$si.FileName = $Adb
$si.Arguments = "-s $Device exec-out screencap -p"
$si.RedirectStandardOutput = $true
$si.UseShellExecute = $false
$p = [Diagnostics.Process]::Start($si)
$fs = [IO.File]::Create($Dest)
$p.StandardOutput.BaseStream.CopyTo($fs)
$fs.Close()
$p.WaitForExit()

if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
Get-Process -Name "dart","java" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "Saved $Dest ($([math]::Round((Get-Item $Dest).Length/1KB)) KB)"
