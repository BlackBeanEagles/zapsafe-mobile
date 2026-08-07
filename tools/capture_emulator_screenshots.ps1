# Capture emulator screenshots (flutter run per route, no prebuilt binary).
param([int]$LaunchWaitSec = 150)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$OutDir = Join-Path $Root "screenshots\emulator"
$Adb = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"
$Flutter = "C:\flutter\bin\flutter.bat"
$Device = "emulator-5554"
$Pkg = "com.zapsafe.zapsafe_mobile"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Set-Location $Root

function Save-Shot([string]$Name) {
    $dest = Join-Path $OutDir $Name
    if (Test-Path $dest) { Remove-Item $dest -Force }
    Start-Sleep -Seconds 8
    $si = New-Object System.Diagnostics.ProcessStartInfo
    $si.FileName = $Adb
    $si.Arguments = "-s $Device exec-out screencap -p"
    $si.RedirectStandardOutput = $true
    $si.UseShellExecute = $false
    $p = [Diagnostics.Process]::Start($si)
    $fs = [IO.File]::Create($dest)
    $p.StandardOutput.BaseStream.CopyTo($fs)
    $fs.Close()
    $p.WaitForExit()
    Write-Host "  Saved $Name ($([math]::Round((Get-Item $dest).Length/1KB)) KB)"
}

function Stop-Flutter {
    Get-Process -Name "dart","java" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    & $Adb -s $Device shell am force-stop $Pkg 2>$null | Out-Null
    Start-Sleep 4
}

function Launch-Route([string]$Route, [string]$ExtraDefine = "") {
    Stop-Flutter
    $log = Join-Path $OutDir "_run.log"
    if (Test-Path $log) { Remove-Item $log -Force }

    $args = @("run", "-d", $Device, "--dart-define=INITIAL_ROUTE=$Route")
    if ($ExtraDefine) { $args += "--dart-define=$ExtraDefine" }
    Write-Host "  flutter run $($args -join ' ')"

    $proc = Start-Process -FilePath $Flutter -ArgumentList $args `
        -WorkingDirectory $Root -PassThru -NoNewWindow `
        -RedirectStandardOutput $log

    $deadline = (Get-Date).AddSeconds($LaunchWaitSec)
    $ready = $false
    while ((Get-Date) -lt $deadline -and -not $proc.HasExited) {
        if (Test-Path $log) {
            $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
            if ($text -match "Flutter run key commands") {
                $ready = $true
                break
            }
            if ($text -match "FAILURE|BUILD FAILED") { break }
        }
        Start-Sleep -Seconds 3
    }

    if ($ready) { Start-Sleep -Seconds 15 }
    else { Start-Sleep -Seconds 10 }
    return $proc
}

$shots = @(
    @{ File = "01_nav_index_hero.png"; Route = "/"; Extra = "" },
    @{ File = "02_day300_celebration.png"; Route = "/day-300-milestone"; Extra = "INITIAL_TAB=0" },
    @{ File = "03_day300_stats.png"; Route = "/day-300-milestone"; Extra = "INITIAL_TAB=1" },
    @{ File = "04_day300_phase2.png"; Route = "/day-300-milestone"; Extra = "INITIAL_TAB=2" },
    @{ File = "05_day200_grand_finale.png"; Route = "/grand-finale"; Extra = "" },
    @{ File = "06_day298_gonogo_gate.png"; Route = "/gonogo-gate"; Extra = "" },
    @{ File = "07_day289_regression_runner.png"; Route = "/full-regression-runner"; Extra = "" }
)

foreach ($s in $shots) {
    Write-Host ">>> $($s.File)"
    $proc = Launch-Route -Route $s.Route -ExtraDefine $s.Extra
    Save-Shot -Name $s.File
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Stop-Flutter
}

Write-Host ""
Write-Host "Done - 7 screenshots in $OutDir"
