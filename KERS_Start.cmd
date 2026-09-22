@echo off
REM =====================================================================
REM  KERS Starter
REM  https://github.com/KERSEX/KERS_Mods
REM
REM  Diese eine Datei genuegt. Doppelklick, dann
REM    * fragt sie, ob sie als Administrator laufen soll
REM    * laedt den Werkzeugkasten nach Rueckfrage von GitHub
REM      (nur, wenn er nicht schon daneben liegt)
REM    * startet Mod Manager oder F1 Installer
REM
REM  Batch- und PowerShell-Skript in einer Datei: der Batch-Teil startet
REM  PowerShell, alles ab #@PSBEGIN@ ist PowerShell-Code.
REM =====================================================================
setlocal EnableExtensions
title KERS Starter
set "KERS_SELF=%~f0"

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [FEHLER] Windows PowerShell wurde nicht gefunden.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$src=[IO.File]::ReadAllText($env:KERS_SELF); $i=$src.LastIndexOf('#@PS'+'BEGIN@'); Invoke-Expression $src.Substring($i)"
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

#@PSBEGIN@
# =====================================================================
#  KERS Starter - holt den Werkzeugkasten und startet ihn
#  Eine Datei genuegt: liegt der Rest nicht daneben, wird er nach
#  Rueckfrage von GitHub geladen.
# =====================================================================
$ErrorActionPreference = 'Stop'
$script:StarterVersion = '1.0'
$script:RepoUrl = 'https://github.com/KERSEX/KERS_Mods'
$script:ZipUrl  = 'https://github.com/KERSEX/KERS_Mods/archive/refs/heads/main.zip'
$script:ApiUrl  = 'https://api.github.com/repos/KERSEX/KERS_Mods/commits/main'

try { $Host.UI.RawUI.WindowTitle = 'KERS Starter' } catch { }

$script:DataDir = $env:LOCALAPPDATA
if (-not $script:DataDir) { $script:DataDir = $env:TEMP }
if (-not $script:DataDir) { $script:DataDir = '.' }
$script:AppDir  = Join-Path $script:DataDir 'KERS_Mods\app'
$script:VerFile = Join-Path $script:AppDir '.kers_version.json'

function Write-Head {
    param([string]$T)
    Write-Host ''
    Write-Host ('  ' + $T) -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * $T.Length)) -ForegroundColor DarkCyan
}
function Write-Ok   { param([string]$T) Write-Host ('  [OK] ' + $T) -ForegroundColor Green }
function Write-Info { param([string]$T) Write-Host ('  [i] ' + $T) -ForegroundColor Gray }
function Write-Warn { param([string]$T) Write-Host ('  [!] ' + $T) -ForegroundColor Yellow }
function Write-Err  { param([string]$T) Write-Host ('  [FEHLER] ' + $T) -ForegroundColor Red }
function Write-Dim  { param([string]$T) Write-Host ('  ' + $T) -ForegroundColor DarkGray }

$script:NullReads = 0
function Read-Line {
    $v = $null
    try { $v = Read-Host } catch { $v = $null }
    if ($null -eq $v) {
        $script:NullReads++
        if ($script:NullReads -ge 3) { throw 'Keine Eingabe moeglich - Abbruch.' }
        return ''
    }
    $script:NullReads = 0
    return [string]$v
}
function Read-Key {
    param([string]$Prompt, [string[]]$Valid, [string]$Default = '')
    while ($true) {
        Write-Host ''
        if ($Default) { Write-Host ("$Prompt [$Default] : ") -NoNewline -ForegroundColor Yellow }
        else          { Write-Host ("$Prompt : ")            -NoNewline -ForegroundColor Yellow }
        $raw = (Read-Line).Trim()
        if ($raw -eq '' -and $Default) { return $Default }
        foreach ($v in $Valid) { if ($raw -ieq $v) { return $v.ToUpper() } }
        Write-Host ('  Moeglich: ' + ($Valid -join ', ')) -ForegroundColor Red
    }
}
function Read-YesNo {
    param([string]$Prompt, [bool]$Default = $true)
    $hint = if ($Default) { '[J/n]' } else { '[j/N]' }
    while ($true) {
        Write-Host ''
        Write-Host ("$Prompt $hint : ") -NoNewline -ForegroundColor Yellow
        $raw = (Read-Line).Trim().ToLower()
        if ($raw -eq '') { return $Default }
        if ($raw -in @('j', 'ja', 'y', 'yes')) { return $true }
        if ($raw -in @('n', 'nein', 'no'))     { return $false }
    }
}

function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Invoke-Elevate {
    $self = $env:KERS_SELF
    if (-not $self -or -not (Test-Path -LiteralPath $self)) { return $false }
    try {
        [void](Start-Process -FilePath $self -Verb RunAs -PassThru)
        return $true
    } catch {
        return $false
    }
}

function Show-Banner {
    try { Clear-Host } catch { }
    Write-Host ''
    Write-Host '  ==============================================================' -ForegroundColor Cyan
    Write-Host '   KERS STARTER' -ForegroundColor White
    Write-Host '   Werkzeugkasten fuers Modden und Einstellen von Spielen' -ForegroundColor Gray
    Write-Host ('   v' + $script:StarterVersion + '   ' + $script:RepoUrl) -ForegroundColor DarkGray
    Write-Host '  ==============================================================' -ForegroundColor Cyan
    if (Test-Admin) {
        Write-Dim 'Laeuft mit Administrator-Rechten.'
    } else {
        Write-Dim 'Laeuft ohne Administrator-Rechte.'
    }
}

# ---------------------------------------------------------------------
#  Werkzeugkasten finden, laden, aktualisieren
# ---------------------------------------------------------------------
function Test-KersRoot {
    param([string]$Path)
    if (-not $Path) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Path 'Tools\KERS_Mod_Manager\manager.ps1'))
}

function Get-KersRoot {
    $self = $env:KERS_SELF
    if ($self) {
        $beside = Split-Path $self -Parent
        if (Test-KersRoot $beside) { return $beside }
    }
    if (Test-KersRoot $script:AppDir) { return $script:AppDir }
    return $null
}

function Format-KersDate {
    # ConvertFrom-Json macht aus dem Zeitstempel je nach Version einen
    # DateTime - beides soll gleich aussehen
    param($Value)
    if (-not $Value) { return '' }
    try { return ([datetime]$Value).ToString('yyyy-MM-dd HH:mm') } catch { return [string]$Value }
}

function Get-InstalledInfo {
    if (-not (Test-Path -LiteralPath $script:VerFile)) { return $null }
    try { return (Get-Content -LiteralPath $script:VerFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Get-RemoteSha {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch { }
    try {
        $r = Invoke-RestMethod -Uri $script:ApiUrl -Headers @{ 'User-Agent' = 'KERS-Starter' } -TimeoutSec 20
        if ($r.sha) { return [string]$r.sha }
    } catch { }
    return ''
}

function Install-KersTools {
    param([switch]$IsUpdate)

    Write-Head $(if ($IsUpdate) { 'Werkzeuge aktualisieren' } else { 'Werkzeuge herunterladen' })
    Write-Dim 'Geladen wird ausschliesslich das Projekt-Archiv von GitHub:'
    Write-Host ('  ' + $script:ZipUrl) -ForegroundColor White
    Write-Dim ('Ziel: ' + $script:AppDir)
    Write-Dim 'Ausgefuehrt wird dabei nichts - es werden nur Dateien entpackt.'
    if (-not (Read-YesNo '  Jetzt herunterladen?' $true)) { return $false }

    $zip = Join-Path $env:TEMP ('kers_mods_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.zip')
    $tmp = Join-Path $env:TEMP ('kers_mods_x_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
        Write-Dim 'Lade ...'
        $pp = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $script:ZipUrl -OutFile $zip -UseBasicParsing -TimeoutSec 120
        $ProgressPreference = $pp

        $size = (Get-Item -LiteralPath $zip).Length
        if ($size -lt 1024) { throw 'Die heruntergeladene Datei ist zu klein - Download unvollstaendig.' }
        $head = [IO.File]::ReadAllBytes($zip)[0..1]
        if ($head[0] -ne 0x50 -or $head[1] -ne 0x4B) { throw 'Die heruntergeladene Datei ist kein ZIP-Archiv.' }
        Write-Ok ([string][math]::Round($size / 1KB) + ' KB geladen')

        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
        $inner = @(Get-ChildItem -LiteralPath $tmp -Directory | Where-Object { Test-KersRoot $_.FullName })
        if ($inner.Count -eq 0) { throw 'Im Archiv wurde der Werkzeugkasten nicht gefunden.' }

        if (Test-Path -LiteralPath $script:AppDir) {
            Remove-Item -LiteralPath $script:AppDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:AppDir -Force | Out-Null
        foreach ($item in (Get-ChildItem -LiteralPath $inner[0].FullName -Force)) {
            Copy-Item -LiteralPath $item.FullName -Destination $script:AppDir -Recurse -Force
        }

        $info = [pscustomobject]@{
            date = (Get-Date -Format 's')
            sha  = (Get-RemoteSha)
            url  = $script:ZipUrl
        }
        Set-Content -LiteralPath $script:VerFile -Value (ConvertTo-Json -InputObject $info -Depth 3) -Encoding UTF8
        Write-Ok ('Entpackt nach ' + $script:AppDir)
        return $true
    } catch {
        Write-Err $_.Exception.Message
        Write-Dim 'Alternative: das Repository von Hand als ZIP laden und entpacken,'
        Write-Dim ('dann diese Datei daneben legen: ' + $script:RepoUrl)
        return $false
    } finally {
        foreach ($p in @($zip, $tmp)) {
            if ($p -and (Test-Path -LiteralPath $p)) {
                Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Invoke-UpdateCheck {
    Write-Head 'Auf Updates pruefen'
    $info = Get-InstalledInfo
    if ($info) {
        Write-Dim ('Installiert: ' + (Format-KersDate $info.date) + $(if ($info.sha) { '  (' + $info.sha.Substring(0, 7) + ')' } else { '' }))
    }
    $remote = Get-RemoteSha
    if (-not $remote) {
        Write-Warn 'Der Stand auf GitHub liess sich nicht abfragen (kein Netz oder Limit).'
    } elseif ($info -and $info.sha -eq $remote) {
        Write-Ok 'Alles aktuell.'
        if (-not (Read-YesNo '  Trotzdem neu laden?' $false)) { return }
    } else {
        Write-Info ('Neuer Stand verfuegbar: ' + $remote.Substring(0, 7))
    }
    [void](Install-KersTools -IsUpdate)
}

# ---------------------------------------------------------------------
#  Starten
# ---------------------------------------------------------------------
function Start-ModManager {
    param([string]$Root)
    $ps1 = Join-Path $Root 'Tools\KERS_Mod_Manager\manager.ps1'
    if (-not (Test-Path -LiteralPath $ps1)) { Write-Err ('Nicht gefunden: ' + $ps1); return }
    Write-Head 'KERS Mod Manager'
    try { & $ps1 } catch { Write-Err $_.Exception.Message }
}

function Start-F1Installer {
    param([string]$Root)
    $cmd = Join-Path $Root 'F1\KERS_F1_Mods_Installer.cmd'
    if (-not (Test-Path -LiteralPath $cmd)) { Write-Err ('Nicht gefunden: ' + $cmd); return }
    Write-Head 'F1 Mods Installer'
    Write-Dim 'Laeuft in einem eigenen Fenster.'
    try {
        Start-Process -FilePath $env:ComSpec -ArgumentList @('/c', $cmd) -Wait
        Write-Ok 'Beendet.'
    } catch { Write-Err $_.Exception.Message }
}

function Invoke-Main {
    Show-Banner

    if (-not (Test-Admin)) {
        Write-Host ''
        Write-Info 'Administrator-Rechte werden gebraucht fuer Aenderungen in'
        Write-Dim  '    "Program Files": F1-Wheel-Fix und Mods im Spielordner.'
        Write-Dim  '    Alles, was nur deine Einstellungen betrifft, geht auch ohne.'
        if (Read-YesNo '  Als Administrator neu starten?' $true) {
            if (Invoke-Elevate) { return 0 }
            Write-Warn 'Neustart als Administrator hat nicht geklappt - mache ohne weiter.'
        }
    }

    while ($true) {
        $root = Get-KersRoot
        Write-Host ''
        if ($root) {
            Write-Dim ('Werkzeuge: ' + $root)
            $info = Get-InstalledInfo
            if ($info -and $root -eq $script:AppDir) { Write-Dim ('Stand: ' + (Format-KersDate $info.date)) }
        } else {
            Write-Warn 'Der Werkzeugkasten ist noch nicht da.'
        }

        Write-Host ''
        if ($root) {
            Write-Host '   1) Mod Manager starten (alle Spiele)' -ForegroundColor White
            Write-Host '   2) F1 Mods Installer starten (MOZA Wheel-Fix, Grafik-Preset)' -ForegroundColor White
            Write-Host '   3) Auf Updates pruefen / neu laden' -ForegroundColor White
            Write-Host '   4) Ordner oeffnen' -ForegroundColor White
        } else {
            Write-Host '   3) Werkzeuge jetzt herunterladen' -ForegroundColor White
        }
        if (-not (Test-Admin)) {
            Write-Host '   A) Als Administrator neu starten' -ForegroundColor White
        }
        Write-Host ''
        Write-Host '   0) Beenden' -ForegroundColor White

        $keys = @('3', '0')
        if ($root) { $keys = @('1', '2', '3', '4', '0') }
        if (-not (Test-Admin)) { $keys += 'A' }
        $sel = Read-Key '  Auswahl' $keys $(if ($root) { '1' } else { '3' })

        switch ($sel) {
            '0' { return 0 }
            '1' { Start-ModManager $root }
            '2' { Start-F1Installer $root }
            '3' { [void](Install-KersTools) }
            '4' {
                try { Start-Process explorer.exe $root } catch { Write-Err $_.Exception.Message }
            }
            'A' {
                if (Invoke-Elevate) { return 0 }
                Write-Warn 'Neustart als Administrator hat nicht geklappt.'
            }
        }
        if ($sel -eq '3' -and -not (Get-KersRoot)) { continue }
        Write-Host ''
        Write-Host '  Weiter mit Enter ...' -NoNewline -ForegroundColor DarkGray
        [void](Read-Line)
        Show-Banner
    }
}

$exit = 0
try {
    $exit = Invoke-Main
} catch {
    Write-Host ''
    Write-Err $_.Exception.Message
    $exit = 1
}
Write-Host ''
Write-Host '  Beliebige Taste zum Beenden ...' -ForegroundColor DarkGray
try { [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { [void](Read-Line) }
exit $exit
