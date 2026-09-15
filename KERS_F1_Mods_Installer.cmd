@echo off
REM =====================================================================
REM  KERS F1 Mods Installer - Werkzeugkasten fuer F1 2015 - F1 26
REM  https://github.com/kersex/KERS_Mods
REM
REM  Einfach doppelklicken. Das Tool
REM    * erkennt die angeschlossene MOZA Wheelbase (VID 346E) automatisch
REM      und installiert den Wheel-Fix in jedes gefundene F1-Spiel
REM    * laesst dich waehlen, als welches Lenkrad die Base emuliert wird
REM    * setzt das KERS-Grafik-Preset (FSR oder DLSS je nach GPU, UDP an)
REM    * sichert und stellt Grafik-/Spiel-Einstellungen wieder her (Presets)
REM    * zeigt, was in "Dokumente\My Games" liegt (Diagnose)
REM
REM  Diese Datei ist gleichzeitig Batch- und PowerShell-Skript:
REM  der Batch-Teil startet PowerShell, der Rest ab #@PSBEGIN@ ist der Code.
REM =====================================================================
setlocal EnableExtensions
title KERS F1 Mods Installer
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
#  KERS F1 Mods Installer - Werkzeugkasten fuer F1 2015 - F1 26
#  https://github.com/kersex/KERS_Mods
#
#  - MOZA Wheel-Fix: Base erkennen (VID 346E), Actionmap in jedes
#    gefundene F1-Spiel schreiben, Lenkrad-Emulation frei waehlbar
#  - Presets: Grafik- und Spiel-Einstellungen sichern und
#    wiederherstellen (Dokumente\My Games\F1 20xx)
#  - Diagnose: zeigt, welche Einstellungsdateien ein Spiel anlegt
# =====================================================================

$ErrorActionPreference = 'Stop'
$script:KersVersion = '1.0'
$script:MozaVid     = '346E'
$script:DiSuffix    = '-0000-0000-0000-504944564944'
$script:DataDir     = $env:LOCALAPPDATA
if (-not $script:DataDir) { $script:DataDir = $env:TEMP }
if (-not $script:DataDir) { $script:DataDir = '.' }
$script:LogFile     = Join-Path $script:DataDir 'KERS_Mods\moza_f1_installer.log'
$script:Manifest    = Join-Path $script:DataDir 'KERS_Mods\moza_f1_install.json'
$script:PresetRoot  = Join-Path $script:DataDir 'KERS_Mods\presets'
$script:Stamp       = Get-Date -Format 'yyyyMMdd_HHmmss'

try { $Host.UI.RawUI.WindowTitle = 'KERS F1 Mods Installer' } catch { }

# ---------------------------------------------------------------------
#  bekannte MOZA Product-IDs (VID 346E).  Die PID wird am Geraet
#  ausgelesen - diese Tabelle liefert nur den huebschen Namen.
# ---------------------------------------------------------------------
$script:MozaModels = [ordered]@{
    '0000' = @{ Slug = 'r16_r21'; Label = 'MOZA R16 / R21' }
    '0002' = @{ Slug = 'r9';      Label = 'MOZA R9 / R9 V2' }
    '0004' = @{ Slug = 'r5';      Label = 'MOZA R5' }
    '0005' = @{ Slug = 'r3';      Label = 'MOZA R3' }
    '0006' = @{ Slug = 'r12';     Label = 'MOZA R12' }
    '0007' = @{ Slug = 'r8';      Label = 'MOZA R8' }
    '0010' = @{ Slug = 'r16_r21'; Label = 'MOZA R16 / R21 (alt. Firmware-ID)' }
    '0012' = @{ Slug = 'r9';      Label = 'MOZA R9 (alt. Firmware-ID)' }
    '0014' = @{ Slug = 'r5';      Label = 'MOZA R5 (alt. Firmware-ID)' }
    '0015' = @{ Slug = 'r3';      Label = 'MOZA R3 (alt. Firmware-ID)' }
    '0016' = @{ Slug = 'r12';     Label = 'MOZA R12 (alt. Firmware-ID)' }
}

# ---------------------------------------------------------------------
#  F1-Spiele, die die actionmaps-Struktur benutzen
# ---------------------------------------------------------------------
$script:F1FolderPattern = '^F1[ _\-]?(2015|2016|2017|2018|2019|2020|2021|22|23|24|25|26)$'

function Write-Log {
    param([string]$Text)
    try {
        $dir = Split-Path $script:LogFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $script:LogFile -Value ("[{0}] {1}" -f (Get-Date -Format 's'), $Text) -Encoding UTF8
    } catch { }
}

function Write-Head {
    param([string]$Text)
    Write-Host ''
    Write-Host ('  ' + $Text) -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * $Text.Length)) -ForegroundColor DarkCyan
}

function Show-Banner {
    try { Clear-Host } catch { }
    Write-Host ''
    Write-Host '  ==============================================================' -ForegroundColor Cyan
    Write-Host '   KERS F1 Mods Installer' -ForegroundColor White
    Write-Host '   F1 2015 - F1 26   |   Wheel-Fix, Presets, Diagnose' -ForegroundColor Gray
    Write-Host ('   v' + $script:KersVersion + '   github.com/kersex/KERS_Mods') -ForegroundColor DarkGray
    Write-Host '  ==============================================================' -ForegroundColor Cyan
}

function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Invoke-Elevate {
    # startet dieselbe .cmd noch einmal als Administrator
    $self = $env:KERS_SELF
    if (-not $self -or -not (Test-Path $self)) { return $false }
    try {
        $psi = Start-Process -FilePath $env:ComSpec -ArgumentList @('/c', ('""' + $self + '""')) -Verb RunAs -PassThru
        return ($null -ne $psi)
    } catch {
        return $false
    }
}

$script:NullReads = 0
function Read-Line {
    # Read-Host liefert $null, wenn die Eingabe nicht mehr moeglich ist
    # (geschlossene Konsole / umgeleitetes stdin) - das darf keine
    # Endlosschleife und keinen Null-Aufruf geben.
    $v = $null
    try { $v = Read-Host } catch { $v = $null }
    if ($null -eq $v) {
        $script:NullReads++
        if ($script:NullReads -ge 3) { throw 'Keine Eingabe moeglich (Konsole geschlossen?) - Abbruch.' }
        return ''
    }
    $script:NullReads = 0
    return [string]$v
}

function Read-Choice {
    param([string]$Prompt, [int]$Min, [int]$Max, [int]$Default = -1)
    while ($true) {
        if ($Default -ge 0) { $p = "$Prompt [$Default]: " } else { $p = "$Prompt : " }
        Write-Host ''
        Write-Host $p -NoNewline -ForegroundColor Yellow
        $raw = Read-Line
        if ([string]::IsNullOrWhiteSpace($raw) -and $Default -ge 0) { return $Default }
        $n = 0
        if ([int]::TryParse($raw.Trim(), [ref]$n)) {
            if ($n -ge $Min -and $n -le $Max) { return $n }
        }
        Write-Host ('  Bitte eine Zahl zwischen ' + $Min + ' und ' + $Max + ' eingeben.') -ForegroundColor Red
    }
}

function Read-YesNo {
    param([string]$Prompt, [bool]$Default = $true)
    if ($Default) { $hint = '[J/n]' } else { $hint = '[j/N]' }
    while ($true) {
        Write-Host ''
        Write-Host ("$Prompt $hint : ") -NoNewline -ForegroundColor Yellow
        $raw = (Read-Line).Trim().ToLower()
        if ($raw -eq '') { return $Default }
        if ($raw -in @('j','ja','y','yes')) { return $true }
        if ($raw -in @('n','nein','no'))    { return $false }
        Write-Host '  Bitte J (ja) oder N (nein) eingeben.' -ForegroundColor Red
    }
}

# ---------------------------------------------------------------------
#  Datei-IO: byte-treu lesen/schreiben (Codemasters-XMLs sind ANSI)
# ---------------------------------------------------------------------
function Read-XmlText {
    param([string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return @{ Text = [Text.Encoding]::Unicode.GetString($bytes); Mode = 'utf16le' }
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return @{ Text = [Text.Encoding]::BigEndianUnicode.GetString($bytes); Mode = 'utf16be' }
    }
    # Latin-1 bildet jedes Byte 1:1 auf ein Zeichen ab -> verlustfrei,
    # auch bei UTF-8 Dateien (wir aendern nur ASCII-Attribute).
    return @{ Text = [Text.Encoding]::GetEncoding(28591).GetString($bytes); Mode = 'raw' }
}

function Write-XmlText {
    param([string]$Path, [string]$Text, [string]$Mode = 'raw')
    switch ($Mode) {
        'utf16le' { [IO.File]::WriteAllBytes($Path, [Text.Encoding]::Unicode.GetBytes($Text)) }
        'utf16be' { [IO.File]::WriteAllBytes($Path, [Text.Encoding]::BigEndianUnicode.GetBytes($Text)) }
        default   { [IO.File]::WriteAllBytes($Path, [Text.Encoding]::GetEncoding(28591).GetBytes($Text)) }
    }
}

function Get-XmlAttr {
    param([string]$Tag, [string]$Name)
    $m = [regex]::Match($Tag, ('\b' + [regex]::Escape($Name) + '\s*=\s*"([^"]*)"'), 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

# ---------------------------------------------------------------------
#  1) MOZA Wheelbase erkennen
# ---------------------------------------------------------------------
function Get-MozaBases {
    $result = @{}

    # angeschlossene Geraete
    try {
        $pnp = @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue)
        foreach ($d in $pnp) {
            $hwid = [string]$d.PNPDeviceID
            $m = [regex]::Match($hwid, 'VID_346E&PID_([0-9A-Fa-f]{4})', 'IgnoreCase')
            if ($m.Success) {
                $key = $m.Groups[1].Value.ToUpper()
                if (-not $result.ContainsKey($key)) {
                    $result[$key] = @{ Pid = $key; Present = $true; Raw = [string]$d.Name }
                } else {
                    $result[$key].Present = $true
                }
            }
        }
    } catch { Write-Log ("PnP-Abfrage fehlgeschlagen: " + $_.Exception.Message) }

    # Registry-Fallback (auch frueher angeschlossene Bases)
    foreach ($root in @('HKLM:\SYSTEM\CurrentControlSet\Enum\HID', 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB')) {
        try {
            if (-not (Test-Path $root)) { continue }
            foreach ($k in (Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
                $m = [regex]::Match($k.PSChildName, 'VID_346E&PID_([0-9A-Fa-f]{4})', 'IgnoreCase')
                if ($m.Success) {
                    $key = $m.Groups[1].Value.ToUpper()
                    if (-not $result.ContainsKey($key)) {
                        $result[$key] = @{ Pid = $key; Present = $false; Raw = 'Registry-Eintrag' }
                    }
                }
            }
        } catch { }
    }

    $list = @()
    foreach ($key in ($result.Keys | Sort-Object)) {
        $info = $result[$key]
        $known = $script:MozaModels[$key]
        if ($known) {
            $slug = $known.Slug
            $label = $known.Label
        } else {
            $slug = ('pid' + $key.ToLower())
            $label = ('MOZA (unbekanntes Modell, PID ' + $key + ')')
        }
        $list += [pscustomobject]@{
            Pid     = $key
            Slug    = $slug
            Label   = $label
            Present = $info.Present
            Guid    = ('{' + $key + $script:MozaVid + $script:DiSuffix + '}')
            Raw     = $info.Raw
        }
    }
    return $list
}

function New-MozaBase {
    param([string]$PidHex, [string]$Slug, [string]$Label)
    $PidHex = $PidHex.ToUpper()
    return [pscustomobject]@{
        Pid     = $PidHex
        Slug    = $Slug
        Label   = $Label
        Present = $false
        Guid    = ('{' + $PidHex + $script:MozaVid + $script:DiSuffix + '}')
        Raw     = 'manuell gewaehlt'
    }
}

function Select-MozaBase {
    Write-Head 'Schritt 1 - MOZA Wheelbase'
    Write-Host '  Suche angeschlossene MOZA Hardware ...' -ForegroundColor DarkGray
    $bases = @(Get-MozaBases)
    $present = @($bases | Where-Object { $_.Present })

    if ($present.Count -eq 1) {
        $b = $present[0]
        Write-Host ('  [OK] Erkannt: ' + $b.Label + '   (PID ' + $b.Pid + ')') -ForegroundColor Green
        Write-Host ('       DirectInput-GUID: ' + $b.Guid) -ForegroundColor DarkGray
        if (Read-YesNo '  Diese Wheelbase verwenden?' $true) { return $b }
    } elseif ($present.Count -gt 1) {
        Write-Host '  [OK] Mehrere MOZA Geraete gefunden:' -ForegroundColor Green
    } else {
        Write-Host '  [!] Keine angeschlossene MOZA Wheelbase gefunden.' -ForegroundColor Yellow
        Write-Host '      (Base eingeschaltet und per USB verbunden? Sonst bitte manuell waehlen.)' -ForegroundColor DarkGray
    }

    # Manuelle Auswahl
    $menu = @()
    foreach ($b in $present) { $menu += $b }
    foreach ($key in $script:MozaModels.Keys) {
        if ($menu | Where-Object { $_.Pid -eq $key }) { continue }
        $m = $script:MozaModels[$key]
        $menu += (New-MozaBase -PidHex $key -Slug $m.Slug -Label $m.Label)
    }
    foreach ($b in $bases) {
        if (-not $b.Present -and -not ($menu | Where-Object { $_.Pid -eq $b.Pid })) { $menu += $b }
    }

    Write-Host ''
    Write-Host '  Welche Wheelbase hast du?' -ForegroundColor White
    Write-Host '  (bei angeschlossener Base wird die PID direkt ausgelesen -' -ForegroundColor DarkGray
    Write-Host '   die Liste ist nur der Fallback)' -ForegroundColor DarkGray
    for ($i = 0; $i -lt $menu.Count; $i++) {
        $tag = ''
        if ($menu[$i].Present) { $tag = '  <- angeschlossen' }
        Write-Host ('   {0,2}) {1,-42} PID {2}{3}' -f ($i + 1), $menu[$i].Label, $menu[$i].Pid, $tag)
    }
    Write-Host ('   {0,2}) Andere / PID manuell eingeben' -f ($menu.Count + 1))

    $sel = Read-Choice '  Auswahl' 1 ($menu.Count + 1)
    if ($sel -le $menu.Count) { return $menu[$sel - 1] }

    while ($true) {
        Write-Host ''
        Write-Host '  PID der Base (4 Hex-Zeichen, z.B. 0005) : ' -NoNewline -ForegroundColor Yellow
        $raw = (Read-Line).Trim()
        if ($raw -match '^[0-9A-Fa-f]{4}$') {
            $known = $script:MozaModels[$raw.ToUpper()]
            if ($known) { return (New-MozaBase -PidHex $raw -Slug $known.Slug -Label $known.Label) }
            return (New-MozaBase -PidHex $raw -Slug ('pid' + $raw.ToLower()) -Label ('MOZA (PID ' + $raw.ToUpper() + ')'))
        }
        Write-Host '  Ungueltig - bitte genau 4 Hex-Zeichen.' -ForegroundColor Red
    }
}

# ---------------------------------------------------------------------
#  2) installierte F1-Spiele finden
# ---------------------------------------------------------------------
function Get-SteamLibraries {
    $libs = @()
    $steam = $null
    foreach ($rk in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            if (Test-Path $rk) {
                $p = (Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue)
                if ($p.SteamPath)     { $steam = $p.SteamPath }
                elseif ($p.InstallPath) { $steam = $p.InstallPath }
                if ($steam) { break }
            }
        } catch { }
    }
    if ($steam) {
        $steam = $steam.Replace('/', '\')
        $libs += $steam
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            try {
                foreach ($line in (Get-Content -Path $vdf -ErrorAction SilentlyContinue)) {
                    $m = [regex]::Match($line, '"path"\s+"([^"]+)"')
                    if ($m.Success) { $libs += $m.Groups[1].Value.Replace('\\', '\') }
                }
            } catch { }
        }
    }
    return ($libs | Select-Object -Unique)
}

function Get-EpicInstallDirs {
    $dirs = @()
    if (-not $env:ProgramData) { return $dirs }
    $mf = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (Test-Path $mf) {
        foreach ($f in (Get-ChildItem -Path $mf -Filter *.item -File -ErrorAction SilentlyContinue)) {
            try {
                $j = Get-Content -Path $f.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                if ($j.InstallLocation) { $dirs += [string]$j.InstallLocation }
            } catch { }
        }
    }
    return ($dirs | Select-Object -Unique)
}

function Get-RegistryGameDirs {
    $dirs = @()
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($r in $roots) {
        try {
            if (-not (Test-Path $r)) { continue }
            foreach ($k in (Get-ChildItem -Path $r -ErrorAction SilentlyContinue)) {
                try {
                    $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                    $dn = [string]$p.DisplayName
                    if ($dn -and ($dn -match '^F1[ _\-]?(2015|2016|2017|2018|2019|2020|2021|22|23|24|25|26)\b')) {
                        if ($p.InstallLocation) { $dirs += [string]$p.InstallLocation }
                    }
                } catch { }
            }
        } catch { }
    }
    return ($dirs | Select-Object -Unique)
}

function Get-ScanRoots {
    $roots = @()
    $drives = @()
    try {
        $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | ForEach-Object { $_.DeviceID })
    } catch { }
    if ($drives.Count -eq 0) { $drives = @('C:', 'D:') }

    $subs = @(
        'Program Files\EA Games',
        'Program Files (x86)\EA Games',
        'Program Files (x86)\Origin Games',
        'Program Files\Origin Games',
        'Program Files\Epic Games',
        'Program Files (x86)\Epic Games',
        'Program Files (x86)\Steam\steamapps\common',
        'Program Files\Steam\steamapps\common',
        'Steam\steamapps\common',
        'SteamLibrary\steamapps\common',
        'Games\Steam\steamapps\common',
        'EA Games', 'Origin Games', 'Epic Games', 'Games', 'GOG Games', 'SteamGames'
    )
    # bewusst per String-Verkettung: Join-Path wirft bei Laufwerken,
    # die es (mehr) nicht gibt
    foreach ($d in $drives) {
        foreach ($s in $subs) { $roots += ($d.TrimEnd('\') + '\' + $s) }
    }
    foreach ($lib in (Get-SteamLibraries)) {
        $roots += ($lib.TrimEnd('\') + '\steamapps\common')
    }
    return ($roots | Select-Object -Unique)
}

function Get-F1Title {
    param([string]$FolderName)
    $m = [regex]::Match($FolderName, $script:F1FolderPattern, 'IgnoreCase')
    if (-not $m.Success) { return $null }
    return ('F1 ' + $m.Groups[1].Value)
}

function Add-GameCandidate {
    param([hashtable]$Bag, [string]$Dir, [string]$Source)
    if ([string]::IsNullOrWhiteSpace($Dir)) { return }
    try {
        if (-not (Test-Path -LiteralPath $Dir)) { return }
        $full = (Resolve-Path -LiteralPath $Dir).Path.TrimEnd('\')
        $am = Join-Path $full 'actionmaps'
        if (-not (Test-Path -LiteralPath $am)) { return }
        $leaf = Split-Path $full -Leaf
        $title = Get-F1Title $leaf
        if (-not $title) {
            # z.B. Epic-Ordner "F12021" oder abweichende Namen
            $m = [regex]::Match($leaf, 'F1[ _\-]?(2015|2016|2017|2018|2019|2020|2021|22|23|24|25|26)', 'IgnoreCase')
            if ($m.Success) { $title = ('F1 ' + $m.Groups[1].Value) } else { $title = $leaf }
        }
        $key = $full.ToLower()
        if ($Bag.ContainsKey($key)) { return }
        $Bag[$key] = [pscustomobject]@{
            Title      = $title
            Path       = $full
            ActionMaps = $am
            Source     = $Source
        }
    } catch { }
}

function Get-F1Games {
    $bag = @{}

    $scanRoots = @()
    try { $scanRoots = @(Get-ScanRoots) } catch { Write-Log ('Scan-Roots: ' + $_.Exception.Message) }
    foreach ($root in $scanRoots) {
        try {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
                if ($d.Name -match 'F1') { Add-GameCandidate -Bag $bag -Dir $d.FullName -Source 'Ordner-Scan' }
            }
        } catch { }
    }
    try {
        foreach ($d in (Get-EpicInstallDirs))  { Add-GameCandidate -Bag $bag -Dir $d -Source 'Epic' }
    } catch { Write-Log ('Epic-Suche fehlgeschlagen: ' + $_.Exception.Message) }
    try {
        foreach ($d in (Get-RegistryGameDirs)) { Add-GameCandidate -Bag $bag -Dir $d -Source 'Registry' }
    } catch { Write-Log ('Registry-Suche fehlgeschlagen: ' + $_.Exception.Message) }

    $games = @($bag.Values | Sort-Object Title)
    return $games
}

# ---------------------------------------------------------------------
#  3) vorhandene Lenkrad-Profile eines Spiels einlesen
# ---------------------------------------------------------------------
$script:LabelFixes = @{
    'csl' = 'CSL'; 'dd' = 'DD'; 'gt' = 'GT'; 'ps3' = 'PS3'; 'ps4' = 'PS4'; 'ps5' = 'PS5';
    'xb1' = 'Xbox One'; 'xbox' = 'Xbox'; 'v2' = 'V2'; 'v25' = 'V2.5'; 'v3' = 'V3';
    'tx' = 'TX'; 'tmx' = 'TMX'; 't300' = 'T300'; 't500' = 'T500'; 't150' = 'T150';
    't80' = 'T80'; 't128' = 'T128'; 't248' = 'T248'; 'ts' = 'TS'; 'xw' = 'XW';
    'g25' = 'G25'; 'g27' = 'G27'; 'g29' = 'G29'; 'g920' = 'G920'; 'g923' = 'G923';
    'sq' = 'SQ'; 'usb' = 'USB'; 'gp' = 'GP'; 'rs' = 'RS'; 'pc' = 'PC';
    'dd1' = 'DD1'; 'dd2' = 'DD2'; 'csw' = 'CSW'; 'csr' = 'CSR'; 'gte' = 'GTE';
    'f1' = 'F1'; 'r3' = 'R3'; 'r5' = 'R5'; 'r9' = 'R9'; 'r12' = 'R12';
    'r16' = 'R16'; 'r21' = 'R21'; 'wrc' = 'WRC'; 'x360' = 'Xbox 360'
}

function Get-PrettyLabel {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return 'Unbekannt' }
    $s = $Raw -replace '^lng_', ''
    $parts = $s -split '[_\s]+'
    $out = @()
    foreach ($p in $parts) {
        if ($p -eq '') { continue }
        $fix = $script:LabelFixes[$p.ToLower()]
        if ($fix) { $out += $fix }
        else { $out += ($p.Substring(0, 1).ToUpper() + $p.Substring(1)) }
    }
    return ($out -join ' ')
}

function Get-DeviceProfiles {
    param([string]$ActionMaps)
    $profiles = @()
    foreach ($f in (Get-ChildItem -LiteralPath $ActionMaps -Filter '*.xml' -File -ErrorAction SilentlyContinue)) {
        if ($f.Name -like 'moza_*') { continue }
        try {
            $doc = Read-XmlText $f.FullName
            $dm = [regex]::Match($doc.Text, '<Device\b[^>]*>', 'IgnoreCase')
            if (-not $dm.Success) { continue }
            $tag = $dm.Value
            $typeid = Get-XmlAttr $tag 'typeid'
            if (-not $typeid) { continue }
            # nur echte DirectInput-Geraete (Lenkraeder), keine Pads/Keyboard
            if ($typeid -notmatch '504944564944') { continue }
            if ($typeid -match ('^\{[0-9A-Fa-f]{4}' + $script:MozaVid)) { continue }
            $name = Get-XmlAttr $tag 'name'
            if (-not $name) { continue }
            # Gamepads und Tastatur sind keine sinnvollen Emulationsziele
            if ($name -match '(?i)(xbox|x360|xinput|gamepad|dualshock|dualsense|keyboard|mouse|steam_controller)') { continue }
            $display = Get-XmlAttr $tag 'display'
            if ($display) { $label = Get-PrettyLabel $display } else { $label = Get-PrettyLabel $name }
            $profiles += [pscustomobject]@{
                Name    = $name
                Label   = $label
                Display = $display
                TypeId  = $typeid
                File    = $f.FullName
            }
        } catch { }
    }
    return ($profiles | Sort-Object Label)
}

function Select-EmulationProfile {
    param($Games)
    Write-Head 'Schritt 3 - Als welches Lenkrad soll die MOZA laufen?'
    Write-Host '  Die MOZA wird dem Spiel als bereits unterstuetztes Lenkrad' -ForegroundColor Gray
    Write-Host '  untergeschoben - damit stimmen Tastenbelegung und Symbole.' -ForegroundColor Gray

    $index = @{}
    foreach ($g in $Games) {
        foreach ($p in (Get-DeviceProfiles $g.ActionMaps)) {
            if (-not $index.ContainsKey($p.Name)) {
                $index[$p.Name] = [pscustomobject]@{ Name = $p.Name; Label = $p.Label; Games = @() }
            }
            $index[$p.Name].Games += $g.Title
        }
    }

    $entries = @($index.Values | Sort-Object @{ Expression = { $_.Games.Count }; Descending = $true }, Label)

    Write-Host ''
    Write-Host '    0) MOZA nativ  -  mitgelieferte KERS-Map (eigenes MOZA-Profil)' -ForegroundColor White
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $e = $entries[$i]
        Write-Host ('   {0,2}) {1,-34} ({2} von {3} Spielen)   [{4}]' -f ($i + 1), $e.Label, $e.Games.Count, $Games.Count, $e.Name)
    }
    if ($entries.Count -eq 0) {
        Write-Host '   (in den gefundenen Spielen wurden keine weiteren Lenkrad-Profile gefunden)' -ForegroundColor DarkGray
    }

    $sel = Read-Choice '  Auswahl' 0 $entries.Count 0
    if ($sel -eq 0) { return $null }
    return $entries[$sel - 1]
}

# ---------------------------------------------------------------------
#  4) Installation
# ---------------------------------------------------------------------
function ConvertTo-SafeName {
    param([string]$Text)
    $x = ($Text -replace '[^A-Za-z0-9_\-]', '_')
    while ($x -match '__') { $x = $x -replace '__', '_' }
    $x = $x.Trim('_')
    if ($x -eq '') { $x = 'KERS_MOZA_F1_MOD' }
    return $x
}

function Get-MozaFiles {
    # alle Actionmap-Dateien eines Spiels, die auf eine MOZA-GUID zeigen -
    # unabhaengig vom Dateinamen (aeltere Installationen hiessen moza_*.xml)
    param([string]$ActionMaps)
    $out = @()
    foreach ($f in (Get-ChildItem -LiteralPath $ActionMaps -Filter '*.xml' -File -ErrorAction SilentlyContinue)) {
        if ($f.Extension -ine '.xml') { continue }
        try {
            $txt = (Read-XmlText $f.FullName).Text
            $dm = [regex]::Match($txt, '<Device\b[^>]*>', 'IgnoreCase')
            if (-not $dm.Success) { continue }
            $tid = Get-XmlAttr $dm.Value 'typeid'
            if ($tid -and ($tid -match ('^\{[0-9A-Fa-f]{4}' + $script:MozaVid + '-'))) { $out += $f }
        } catch { }
    }
    return $out
}

function Get-NativeTemplate {
    $b64 = ($script:NativeXmlB64 -replace '\s', '')
    $bytes = [Convert]::FromBase64String($b64)
    return [Text.Encoding]::GetEncoding(28591).GetString($bytes)
}

function New-MozaXml {
    param($Base, $Source, [string]$ProfileName, [string]$DisplayName)
    # $Source      = $null -> native KERS-Map, sonst geklontes Spiel-Profil
    # $ProfileName = interner Profilname + Dateiname
    # $DisplayName = Name, der im Spiel angezeigt wird; leer -> Originalname
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { $ProfileName = ('moza_' + $Base.Slug) }
    $target = ConvertTo-SafeName $ProfileName
    $shown = $DisplayName
    if ($null -eq $Source) {
        $text = Get-NativeTemplate
        $mode = 'raw'
        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            $disp = ('lng_moza_' + $Base.Slug)
            $shown = $disp
        } else {
            $disp = $DisplayName
        }
        # Anzeige-Key und Profilname der Vorlage ersetzen
        $text = $text.Replace('"lng_moza_r3"', ('"' + $disp + '"'))
        $text = $text.Replace('"moza_r3"', ('"' + $target + '"'))
        $text = [regex]::Replace($text, '\{0005346E-0000-0000-0000-504944564944\}', $Base.Guid, 'IgnoreCase')
        $emulates = 'MOZA nativ (KERS-Map)'
    } else {
        $doc = Read-XmlText $Source.File
        $text = $doc.Text
        $mode = $doc.Mode
        # Geraete-ID auf die MOZA umbiegen (Device + alle ActionMaps)
        $text = [regex]::Replace($text, [regex]::Escape($Source.TypeId), $Base.Guid, 'IgnoreCase')
        # interner Profilname eindeutig machen
        $text = $text.Replace(('"' + $Source.Name + '"'), ('"' + $target + '"'))
        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            # Anzeigename des Originals behalten
            if ($Source.Display) { $shown = (Get-PrettyLabel $Source.Display) } else { $shown = $Source.Label }
        } elseif ($Source.Display) {
            # display= am Device und deviceDisplayKey= in den ActionMaps
            $text = $text.Replace(('"' + $Source.Display + '"'), ('"' + $DisplayName + '"'))
        } else {
            $text = [regex]::Replace($text, '(<Device\b)', ('${1} display="' + $DisplayName + '"'), 'IgnoreCase')
        }
        $emulates = $Source.Label
    }
    return @{ Text = $text; Mode = $mode; FileName = ($target + '.xml'); Emulates = $emulates; Shown = $shown }
}

function Install-ToGame {
    param($Game, $Base, $Source, [string]$ProfileName, [string]$DisplayName, [switch]$DryRun)

    $src = $Source
    if ($null -ne $src) {
        # Profil in genau diesem Spiel suchen (Datei kann je Spiel anders heissen)
        $local = @(Get-DeviceProfiles $Game.ActionMaps)
        $hit = @($local | Where-Object { $_.Name -eq $src.Name })
        if ($hit.Count -gt 0) {
            $src = $hit[0]
        } else {
            $family = ($src.Name -split '_')[0]
            $fam = @($local | Where-Object { $_.Name -like ($family + '*') })
            if ($fam.Count -gt 0) {
                $src = $fam[0]
                Write-Host ('      [i] ' + $src.Label + ' statt gewaehltem Profil (in diesem Spiel nicht vorhanden)') -ForegroundColor DarkYellow
            } else {
                $src = $null
                Write-Host '      [i] Profil in diesem Spiel nicht vorhanden -> native KERS-Map' -ForegroundColor DarkYellow
            }
        }
    }

    $build = New-MozaXml -Base $Base -Source $src -ProfileName $ProfileName -DisplayName $DisplayName
    $dest = Join-Path $Game.ActionMaps $build.FileName

    # Dateien frueherer Installationen: zwei Actionmaps mit derselben
    # Geraete-GUID bringen das Spiel durcheinander
    $stale = @(Get-MozaFiles $Game.ActionMaps | Where-Object { $_.FullName -ine $dest })

    if ($DryRun) {
        foreach ($s in $stale) {
            Write-Host ('      [TEST] wuerde alte MOZA-Datei sichern: ' + $s.Name) -ForegroundColor DarkGray
        }
        Write-Host ('      [TEST] wuerde schreiben: ' + $dest) -ForegroundColor DarkGray
        Write-Host ('             im Spiel als "' + $build.Shown + '" (emuliert: ' + $build.Emulates + ')') -ForegroundColor DarkGray
        return [pscustomobject]@{ Game = $Game.Title; Status = 'Test'; File = $dest; Emulates = $build.Emulates; Shown = $build.Shown }
    }

    try {
        foreach ($s in $stale) {
            Move-Item -LiteralPath $s.FullName -Destination ($s.FullName + '.kersbak_' + $script:Stamp) -Force
            Write-Host ('      alte MOZA-Datei gesichert: ' + $s.Name) -ForegroundColor DarkGray
            Write-Log ('beiseite gelegt: ' + $s.FullName)
        }
        if (Test-Path -LiteralPath $dest) {
            $bak = ($dest + '.kersbak_' + $script:Stamp)
            Copy-Item -LiteralPath $dest -Destination $bak -Force
            Write-Host ('      Backup: ' + (Split-Path $bak -Leaf)) -ForegroundColor DarkGray
        }
        Write-XmlText -Path $dest -Text $build.Text -Mode $build.Mode
        Write-Log ('installiert: ' + $dest + ' (Name: ' + $build.Shown + ', emuliert: ' + $build.Emulates + ')')
        Write-Host ('      [OK] ' + $build.FileName) -ForegroundColor Green
        Write-Host ('           im Spiel als "' + $build.Shown + '"  (emuliert: ' + $build.Emulates + ')') -ForegroundColor Green
        return [pscustomobject]@{ Game = $Game.Title; Status = 'OK'; File = $dest; Emulates = $build.Emulates; Shown = $build.Shown }
    } catch {
        Write-Log ('FEHLER ' + $dest + ': ' + $_.Exception.Message)
        Write-Host ('      [FEHLER] ' + $_.Exception.Message) -ForegroundColor Red
        return [pscustomobject]@{ Game = $Game.Title; Status = 'Fehler'; File = $dest; Emulates = $build.Emulates; Shown = $build.Shown }
    }
}

function Save-Manifest {
    param($Results)
    try {
        $dir = Split-Path $script:Manifest -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $old = @()
        if (Test-Path $script:Manifest) {
            try { $old = @(Get-Content -Path $script:Manifest -Raw | ConvertFrom-Json) } catch { $old = @() }
        }
        $all = @()
        foreach ($o in $old) { if ($o -and $o.File) { $all += $o } }
        foreach ($r in $Results) {
            if ($r.Status -ne 'OK') { continue }
            $all = @($all | Where-Object { $_.File -ne $r.File })
            $all += [pscustomobject]@{ Game = $r.Game; File = $r.File; Emulates = $r.Emulates; Date = (Get-Date -Format 's') }
        }
        $json = ConvertTo-Json -InputObject @($all) -Depth 4
        Set-Content -Path $script:Manifest -Value $json -Encoding UTF8
    } catch { }
}

function Remove-ManifestEntries {
    param($Games)
    try {
        if (-not (Test-Path $script:Manifest)) { return }
        $old = @(Get-Content -Path $script:Manifest -Raw | ConvertFrom-Json)
        $paths = @($Games | ForEach-Object { $_.ActionMaps.ToLower() })
        $keep = @($old | Where-Object {
            $_ -and $_.File -and -not ($paths -contains (Split-Path $_.File -Parent).ToLower())
        })
        $json = ConvertTo-Json -InputObject @($keep) -Depth 4
        Set-Content -Path $script:Manifest -Value $json -Encoding UTF8
    } catch { }
}

function Invoke-Uninstall {
    param($Games)
    Write-Head 'Deinstallation'
    $count = 0
    foreach ($g in $Games) {
        $files = @(Get-MozaFiles $g.ActionMaps)
        $baks  = @(Get-ChildItem -LiteralPath $g.ActionMaps -Filter '*.kersbak_*' -File -ErrorAction SilentlyContinue)
        if ($files.Count -eq 0 -and $baks.Count -eq 0) { continue }
        Write-Host ('  ' + $g.Title + '  (' + $g.Path + ')') -ForegroundColor White
        foreach ($f in $files) {
            # die MOZA-Actionmap gehoert nicht zum Spiel - entfernen stellt
            # den Originalzustand wieder her
            try {
                Remove-Item -LiteralPath $f.FullName -Force
                Write-Host ('      [OK] entfernt: ' + $f.Name) -ForegroundColor Green
                Write-Log ('entfernt: ' + $f.FullName)
                $count++
            } catch {
                Write-Host ('      [FEHLER] ' + $_.Exception.Message) -ForegroundColor Red
            }
        }
        foreach ($b in $baks) {
            try {
                Remove-Item -LiteralPath $b.FullName -Force
                Write-Host ('      [OK] Backup entfernt: ' + $b.Name) -ForegroundColor DarkGray
                $count++
            } catch { }
        }
    }
    Remove-ManifestEntries -Games $Games
    if ($count -eq 0) { Write-Host '  Nichts gefunden, was entfernt werden muesste.' -ForegroundColor Gray }
}

# ---------------------------------------------------------------------
#  eingebettete native MOZA-Actionmap (KERS-Map, Base64)
# ---------------------------------------------------------------------
$script:NativeXmlB64 = @'
PCEtLQ0KICAgICoqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqDQogICAgKiBUbyBlbnN1cmUgdGhlIHVzZSBvZiB0
aGlzIHRvb2x0aXAgbWFwIGluIHRoZSBnYW1lIG1ha2Ugc3VyZSB0aGUgZmlsZSBuYW1lIGlzIHZhbGlkIGluIHRoZSBkaWN0aW9uYXJ5IGZpbGUgYW5kIHRo
YXQgdGhlIGRhdGFiYXNlIGhhcyBiZWVuIG1vZGlmaWVkIGNvcnJlY3RseS4NCiAgICAqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioq
KioqKioqKioqKg0KICAgIC0tPg0KICAgIDwhLS0NCiAgICAqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKg0KICAg
ICogVG8gZW5zdXJlIHRoZSB1c2Ugb2YgdGhpcyB0b29sdGlwIG1hcCBpbiB0aGUgZ2FtZSBtYWtlIHN1cmUgdGhlIGZpbGUgbmFtZSBpcyB2YWxpZCBpbiB0
aGUgZGljdGlvbmFyeSBmaWxlIGFuZCB0aGF0IHRoZSBkYXRhYmFzZSBoYXMgYmVlbiBtb2RpZmllZCBjb3JyZWN0bHkuDQogICAgKioqKioqKioqKioqKioq
KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKioNCiAgICAtLT4NCjxEZXZpY2UgbmFtZT0ibW96YV9yMyIgdHlwZWlkPSJ7MDAwNTM0NkUtMDAw
MC0wMDAwLTAwMDAtNTA0OTQ0NTY0OTQ0fSIgZGlzcGxheT0ibG5nX21vemFfcjMiPg0KICAgIDxUb29sdGlwcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlf
YnV0dG9uXzAiPg0KICAgICAgICAgICAgPGljb24gVmFsdWU9IjUiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiAvPg0KICAgICAgICAg
IDxpc19idXR0b24gVmFsdWU9InRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzEiPg0KICAgICAgICAg
ICAgPGljb24gVmFsdWU9IjYiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRy
dWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfeF9heGlzKyI+DQogICAgICAgICAgPGljb24gVmFsdWU9IiZhbXA7IiAv
Pg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJmYWxzZSIgLz4NCiAgICAgICAgPC9B
eGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV94X2F4aXMtIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iJCIgLz4NCiAgICAgICAgICA8bG9jYWxpc2Ug
VmFsdWU9InRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0iZmFsc2UiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFt
ZT0iZGlfeV9heGlzKyI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsOiIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgLz4NCiAgICAg
ICAgICA8aXNfYnV0dG9uIFZhbHVlPSJmYWxzZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV95X2F4aXMtIj4NCiAgICAg
ICAgICA8aWNvbiBWYWx1ZT0iKSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0i
ZmFsc2UiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfel9heGlzKyI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsOoIi8+
DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9ImZhbHNlIiAvPg0KICAgICAgICA8L0F4
aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX3pfYXhpcy0iPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLDqiIgLz4NCiAgICAgICAgICA8bG9jYWxpc2Ug
VmFsdWU9InRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0iZmFsc2UiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFt
ZT0iZGlfeF9heGlzX3JvdGF0aW9uKyI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsOdIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIg
Lz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJmYWxzZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV94X2F4aXNf
cm90YXRpb24tIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw58iIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiAvPg0KICAgICAgICAg
IDxpc19idXR0b24gVmFsdWU9ImZhbHNlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX3lfYXhpc19yb3RhdGlvbisiPg0K
ICAgICAgICAgIDxpY29uIFZhbHVlPSLDoyIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBW
YWx1ZT0iZmFsc2UiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfeV9heGlzX3JvdGF0aW9uLSI+DQogICAgICAgICAgPGlj
b24gVmFsdWU9IsOlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJmYWxzZSIg
Lz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV96X2F4aXNfcm90YXRpb24rIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw6ki
IC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9ImZhbHNlIiAvPg0KICAgICAgICA8
L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX3pfYXhpc19yb3RhdGlvbi0iPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSJeIiAvPg0KICAgICAgICAg
IDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJmYWxzZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAg
ICA8QXhpcyBOYW1lPSJkaV9zbGlkZXJfMCsiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLDtCIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRy
dWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0iZmFsc2UiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfc2xp
ZGVyXzAtIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw7QiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiAvPg0KICAgICAgICAgIDxp
c19idXR0b24gVmFsdWU9ImZhbHNlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX3NsaWRlcl8xIj4NCiAgICAgICAgICA8
aWNvbiBWYWx1ZT0iw5giIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9ImZhbHNl
IiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX3Bvdl8wIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw5MiIFJlYWRPbmx5
PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFs
dWU9ImZhbHNlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9wb3ZfMSI+DQogICAgICAgICAg
PGljb24gVmFsdWU9IsOUIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4N
CiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJmYWxzZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFt
ZT0iZGlfcG92XzIiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLDlSIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0i
dHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0iZmFsc2UiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8
L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX3Bvdl8zIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw5YiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAg
ICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9ImZhbHNlIiBSZWFk
T25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9kcGFkXzBfZG93biI+DQogICAgICAgICAgPGljb24gVmFs
dWU9ImoiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAg
IDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2RwYWRf
MF9sZWZ0Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iayIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIg
UmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4N
CiAgICAgICAgPEF4aXMgTmFtZT0iZGlfZHBhZF8wX3JpZ2h0Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iaSIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAg
ICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9u
bHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfZHBhZF8wX3VwIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0i
aCIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlz
X2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfZHBhZF8xX2Rv
d24iPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSJqIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFk
T25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAg
ICAgICA8QXhpcyBOYW1lPSJkaV9kcGFkXzFfbGVmdCI+DQogICAgICAgICAgPGljb24gVmFsdWU9ImsiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAg
ICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJU
cnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2RwYWRfMV9yaWdodCI+DQogICAgICAgICAgPGljb24gVmFsdWU9Imki
IFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19i
dXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2RwYWRfMV91cCI+
DQogICAgICAgICAgPGljb24gVmFsdWU9ImgiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5
PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAg
IDxBeGlzIE5hbWU9ImRpX2RwYWRfMl9kb3duIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iaiIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxs
b2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUi
IC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfZHBhZF8yX2xlZnQiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSJrIiBSZWFk
T25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9u
IFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9kcGFkXzJfcmlnaHQiPg0K
ICAgICAgICAgIDxpY29uIFZhbHVlPSJpIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0i
VHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8
QXhpcyBOYW1lPSJkaV9kcGFkXzJfdXAiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSJoIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2Fs
aXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4N
CiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9kcGFkXzNfZG93biI+DQogICAgICAgICAgPGljb24gVmFsdWU9ImoiIFJlYWRPbmx5
PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFs
dWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2RwYWRfM19sZWZ0Ij4NCiAgICAg
ICAgICA8aWNvbiBWYWx1ZT0iayIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUi
IC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMg
TmFtZT0iZGlfZHBhZF8zX3JpZ2h0Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iaSIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlz
ZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQog
ICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfZHBhZF8zX3VwIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iaCIgUmVhZE9ubHk9IkZh
bHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0i
dHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzIiPg0KICAgICAgICAgIDxp
Y29uIFZhbHVlPSI3IiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAg
ICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJk
aV9idXR0b25fMyI+DQogICAgICAgICAgPGljb24gVmFsdWU9IjgiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRy
dWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4
aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl80Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iYiIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAg
ICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9u
bHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzUiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSJh
IiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNf
YnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fNiI+
DQogICAgICAgICAgPGljb24gVmFsdWU9IjkiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5
PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAg
IDxBeGlzIE5hbWU9ImRpX2J1dHRvbl83Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iMCIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2Nh
bGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+
DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzgiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSJkIiBSZWFkT25seT0i
RmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVl
PSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fOSI+DQogICAgICAgICAg
PGljb24gVmFsdWU9ImMiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0K
ICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9
ImRpX2J1dHRvbl8xMCI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsKxIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVl
PSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAg
PC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fMTEiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLCsiIgUmVhZE9ubHk9IkZhbHNlIiAv
Pg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIg
UmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzEyIj4NCiAgICAgICAgICA8aWNvbiBW
YWx1ZT0iwrMiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAg
ICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1
dHRvbl8xMyI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsK0IiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVl
IiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlz
Pg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fMTQiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLCtSIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAg
ICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9u
bHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzE1Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0i
wrYiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxp
c19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl8x
NiI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsK5IiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFk
T25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAg
ICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fMTciPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLCuiIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAg
IDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRy
dWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzE4Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw78iIFJl
YWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0
b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl8xOSI+DQog
ICAgICAgICAgPGljb24gVmFsdWU9IsOtIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0i
VHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8
QXhpcyBOYW1lPSJkaV9idXR0b25fMjAiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLEgSIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2Nh
bGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+
DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzIxIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw70iIFJlYWRPbmx5
PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFs
dWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl8yMiI+DQogICAgICAg
ICAgPGljb24gVmFsdWU9IsO8IiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIg
Lz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBO
YW1lPSJkaV9idXR0b25fMjMiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLDgCIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBW
YWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAg
ICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzI0Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw4EiIFJlYWRPbmx5PSJGYWxz
ZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRy
dWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl8yNSI+DQogICAgICAgICAgPGlj
b24gVmFsdWU9IsODIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAg
ICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJk
aV9idXR0b25fMjYiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLDhCIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0i
dHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwv
QXhpcz4NCiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzI3Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw4UiIFJlYWRPbmx5PSJGYWxzZSIgLz4N
CiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJl
YWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl8yOCI+DQogICAgICAgICAgPGljb24gVmFs
dWU9IsOGIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAg
ICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0
b25fMjkiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLDhyIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIg
UmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4N
CiAgICAgICAgPEF4aXMgTmFtZT0iZGlfYnV0dG9uXzMwIj4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw4giIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAg
ICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5
PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl8zMSI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsOJ
IiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNf
YnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fMzIi
Pg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLDiiIgIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFsdWU9InRydWUiIFJlYWRP
bmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICA8L0F4aXM+DQogICAg
ICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl8zMyI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsOLIiBSZWFkT25seT0iRmFsc2UiIC8+DQogICAgICAgICAg
PGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1
ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fMzQiPg0KICAgICAgICAgIDxpY29uIFZhbHVlPSLDjCJSZWFk
T25seT0iRmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9u
IFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fMzUiPg0KICAg
ICAgICAgIDxpY29uIFZhbHVlPSLDjSIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRy
dWUiIC8+DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4
aXMgTmFtZT0iZGlfYnV0dG9uXzM2Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw44iIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxp
c2UgVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0K
ICAgICAgICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl8zNyI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsOPIiBSZWFkT25seT0i
RmFsc2UiIC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVl
PSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgICAgICA8QXhpcyBOYW1lPSJkaV9idXR0b25fMzgiPg0KICAgICAgICAg
IDxpY29uIFZhbHVlPSLDkCIgUmVhZE9ubHk9IkZhbHNlIiAvPg0KICAgICAgICAgIDxsb2NhbGlzZSBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+
DQogICAgICAgICAgPGlzX2J1dHRvbiBWYWx1ZT0idHJ1ZSIgUmVhZE9ubHk9IlRydWUiIC8+DQogICAgICAgIDwvQXhpcz4NCiAgICAgICAgPEF4aXMgTmFt
ZT0iZGlfYnV0dG9uXzM5Ij4NCiAgICAgICAgICA8aWNvbiBWYWx1ZT0iw5EiIFJlYWRPbmx5PSJGYWxzZSIgLz4NCiAgICAgICAgICA8bG9jYWxpc2UgVmFs
dWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAgICAgIDxpc19idXR0b24gVmFsdWU9InRydWUiIFJlYWRPbmx5PSJUcnVlIiAvPg0KICAgICAg
ICA8L0F4aXM+DQogICAgICAgIDxBeGlzIE5hbWU9ImRpX2J1dHRvbl80MCI+DQogICAgICAgICAgPGljb24gVmFsdWU9IsOCIiBSZWFkT25seT0iRmFsc2Ui
IC8+DQogICAgICAgICAgPGxvY2FsaXNlIFZhbHVlPSJ0cnVlIiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgICA8aXNfYnV0dG9uIFZhbHVlPSJ0cnVl
IiBSZWFkT25seT0iVHJ1ZSIgLz4NCiAgICAgICAgPC9BeGlzPg0KICAgIDwvVG9vbHRpcHM+DQogICAgPEZvcmNlRmVlZGJhY2s+DQogICAgICAgIDxTdHJl
bmd0aCB2YWx1ZT0iNTAiIC8+DQogICAgICAgIDxPblRyYWNrIHZhbHVlPSI3NSIgLz4NCiAgICAgICAgPFJ1bWJsZXN0cmlwIHZhbHVlPSI3MCIgLz4NCiAg
ICAgICAgPE9mZlRyYWNrIHZhbHVlPSI3MCIgLz4NCiAgICAgICAgPFdoZWVsV2VpZ2h0IHZhbHVlPSIzIiAvPg0KICAgICAgICA8VW5kZXJzdGVhckVuaGFu
Y2UgdmFsdWU9InRydWUiIC8+DQogICAgPC9Gb3JjZUZlZWRiYWNrPg0KICAgIDxBY3Rpb25NYXBzPg0KICAgICAgICA8QWN0aW9uTWFwIGFjdGlvbk1hcE5h
bWU9Im1vemFfcjMiIGRldmljZU5hbWU9InswMDA1MzQ2RS0wMDAwLTAwMDAtMDAwMC01MDQ5NDQ1NjQ5NDR9IiBkZXZpY2VEaXNwbGF5S2V5PSJsbmdfbW96
YV9yMyIgcHJpb3JpdHk9IjUiPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJNZW51IFJpZ2h0IFN0aWNrIFVwIj4NCiAgICAgICAgICAgICAg
ICA8QXhpcyBheGlzTmFtZT0iZGlfeV9heGlzIiB0eXBlPSJ1bmlEaXJlY3Rpb25hbE5lZ2F0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAi
IC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iTWVudSBSaWdodCBTdGljayBEb3duIj4NCiAgICAg
ICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfel9heGlzX3JvdGF0aW9uIiB0eXBlPSJ1bmlEaXJlY3Rpb25hbE5lZ2F0aXZlIiBkZWFkWm9uZT0iMC4w
IiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iTWVudSBSaWdodCBT
dGljayBMZWZ0Ij4NCiAgICAgICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfeF9heGlzIiB0eXBlPSJiaURpcmVjdGlvbmFsTG93ZXIiIGRlYWRab25l
PSIwLjI1IiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iTWVudSBS
aWdodCBTdGljayBSaWdodCI+DQogICAgICAgICAgICAgICAgPEF4aXMgYXhpc05hbWU9ImRpX3hfYXhpcyIgdHlwZT0iYmlEaXJlY3Rpb25hbFVwcGVyIiBk
ZWFkWm9uZT0iMC4yNSIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9
IkFjY2VsZXJhdGUiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNOYW1lPSJkaV95X2F4aXMiIHR5cGU9InVuaURpcmVjdGlvbmFsTmVnYXRpdmUiIGRl
YWRab25lPSIwLjAiIHNhdHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0aW9uPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJC
cmFrZSI+DQogICAgICAgICAgICAgICAgPEF4aXMgYXhpc05hbWU9ImRpX3pfYXhpc19yb3RhdGlvbiIgdHlwZT0idW5pRGlyZWN0aW9uYWxOZWdhdGl2ZSIg
ZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9
IlN0ZWVyIExlZnQiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNOYW1lPSJkaV94X2F4aXMiIHR5cGU9ImJpRGlyZWN0aW9uYWxMb3dlciIgZGVhZFpv
bmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9IlN0ZWVy
IFJpZ2h0Ij4NCiAgICAgICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfeF9heGlzIiB0eXBlPSJiaURpcmVjdGlvbmFsVXBwZXIiIGRlYWRab25lPSIw
LjAiIHNhdHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0aW9uPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJHZWFyIFVwIj4N
CiAgICAgICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfYnV0dG9uXzQiIHR5cGU9InVuaURpcmVjdGlvbmFsUG9zaXRpdmUiIGRlYWRab25lPSIwLjAi
IHNhdHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0aW9uPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJHZWFyIERvd24iPg0K
ICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNOYW1lPSJkaV9idXR0b25fNSIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIg
c2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9IkNsdXRjaCI+DQogICAg
ICAgICAgICAgICAgPEF4aXMgYXhpc05hbWU9ImRpX2J1dHRvbl80IiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1
cmF0aW9uPSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iRFJTIj4NCiAgICAgICAgICAg
ICAgICA8QXhpcyBheGlzTmFtZT0iZGlfYnV0dG9uXzMiIHR5cGU9InVuaURpcmVjdGlvbmFsUG9zaXRpdmUiIGRlYWRab25lPSIwLjAiIHNhdHVyYXRpb249
IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0aW9uPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJQaXQgTGltaXRlciI+DQogICAgICAgICAg
ICAgICAgPEF4aXMgYXhpc05hbWU9ImRpX2J1dHRvbl8zIiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9u
PSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iVGFsayI+DQogICAgICAgICAgICAgICAg
PEF4aXMgYXhpc05hbWU9ImRpX2J1dHRvbl8yIiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAi
IC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iT3ZlcnRha2UiPg0KICAgICAgICAgICAgICAgIDxB
eGlzIGF4aXNOYW1lPSJkaV9idXR0b25fMCIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAv
Pg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9Ik1GRCBCdXR0b24iPg0KICAgICAgICAgICAgICAgIDxB
eGlzIGF4aXNOYW1lPSJkaV9idXR0b25fMSIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAv
Pg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9Ikxvb2sgRG93biI+DQogICAgICAgICAgICAgICAgPEF4
aXMgYXhpc05hbWU9ImRpX2J1dHRvbl84IiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAiIC8+
DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iUGF1c2UiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4
aXNOYW1lPSJkaV9idXR0b25fNiIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAg
ICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9IlJlcGxheSI+DQogICAgICAgICAgICAgICAgPEF4aXMgYXhpc05h
bWU9ImRpX2J1dHRvbl83IiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAgICAg
ICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iTWVudSBBY2NlcHQiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNO
YW1lPSJkaV9idXR0b25fMCIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAg
ICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9Ik1lbnUgU3RhcnQiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNO
YW1lPSJkaV9idXR0b25fNiIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAg
ICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9Ik1lbnUgQmFjayI+DQogICAgICAgICAgICAgICAgPEF4aXMgYXhpc05h
bWU9ImRpX2J1dHRvbl8xIiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAgICAg
ICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iTWVudSBEUGFkIFVwIj4NCiAgICAgICAgICAgICAgICA8QXhpcyBheGlz
TmFtZT0iZGlfZHBhZF8wX3VwIiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAg
ICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iTWVudSBEUGFkIExlZnQiPg0KICAgICAgICAgICAgICAgIDxBeGlz
IGF4aXNOYW1lPSJkaV9kcGFkXzBfbGVmdCIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAv
Pg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9Ik1lbnUgRFBhZCBSaWdodCI+DQogICAgICAgICAgICAg
ICAgPEF4aXMgYXhpc05hbWU9ImRpX2RwYWRfMF9yaWdodCIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlv
bj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9Ik1lbnUgRFBhZCBEb3duIj4NCiAgICAg
ICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfZHBhZF8wX2Rvd24iIHR5cGU9InVuaURpcmVjdGlvbmFsUG9zaXRpdmUiIGRlYWRab25lPSIwLjAiIHNh
dHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0aW9uPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJNZW51IFVwIj4NCiAgICAg
ICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfZHBhZF8wX3VwIiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1
cmF0aW9uPSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iTWVudSBMZWZ0Ij4NCiAgICAg
ICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfZHBhZF8wX2xlZnQiIHR5cGU9InVuaURpcmVjdGlvbmFsUG9zaXRpdmUiIGRlYWRab25lPSIwLjAiIHNh
dHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0aW9uPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJNZW51IFJpZ2h0Ij4NCiAg
ICAgICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfZHBhZF8wX3JpZ2h0IiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4w
IiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0iTWVudSBEb3duIj4N
CiAgICAgICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfZHBhZF8wX2Rvd24iIHR5cGU9InVuaURpcmVjdGlvbmFsUG9zaXRpdmUiIGRlYWRab25lPSIw
LjAiIHNhdHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0aW9uPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJNRkQgTWVudSBV
cCI+DQogICAgICAgICAgICAgICAgPEF4aXMgYXhpc05hbWU9ImRpX2RwYWRfMF91cCIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9
IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9Ik1GRCBNZW51
IFJpZ2h0Ij4NCiAgICAgICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfZHBhZF8wX3JpZ2h0IiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0aXZlIiBk
ZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9uTmFtZT0i
TUZEIE1lbnUgRG93biI+DQogICAgICAgICAgICAgICAgPEF4aXMgYXhpc05hbWU9ImRpX2RwYWRfMF9kb3duIiB0eXBlPSJ1bmlEaXJlY3Rpb25hbFBvc2l0
aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24gYWN0aW9u
TmFtZT0iTUZEIE1lbnUgTGVmdCI+DQogICAgICAgICAgICAgICAgPEF4aXMgYXhpc05hbWU9ImRpX2RwYWRfMF9sZWZ0IiB0eXBlPSJ1bmlEaXJlY3Rpb25h
bFBvc2l0aXZlIiBkZWFkWm9uZT0iMC4wIiBzYXR1cmF0aW9uPSIxLjAiIC8+DQogICAgICAgICAgICA8L0FjdGlvbj4NCiAgICAgICAgICAgIDxBY3Rpb24g
YWN0aW9uTmFtZT0iTWVudSBFeHRyYTEiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNOYW1lPSJkaV9idXR0b25fMiIgdHlwZT0idW5pRGlyZWN0aW9u
YWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAgICA8QWN0aW9u
IGFjdGlvbk5hbWU9Ik1lbnUgRXh0cmEyIj4NCiAgICAgICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfYnV0dG9uXzMiIHR5cGU9InVuaURpcmVjdGlv
bmFsUG9zaXRpdmUiIGRlYWRab25lPSIwLjAiIHNhdHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0aW9uPg0KICAgICAgICAgICAgPEFjdGlv
biBhY3Rpb25OYW1lPSJNZW51IFNob3VsZGVyIExlZnQiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNOYW1lPSJkaV9idXR0b25fNSIgdHlwZT0idW5p
RGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQogICAgICAgICAg
ICA8QWN0aW9uIGFjdGlvbk5hbWU9Ik1lbnUgU2hvdWxkZXIgUmlnaHQiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNOYW1lPSJkaV9idXR0b25fNCIg
dHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAgICAgPC9BY3Rpb24+DQog
ICAgICAgICAgICA8QWN0aW9uIGFjdGlvbk5hbWU9Ik1lbnUgVHJpZ2dlciBMZWZ0Ij4NCiAgICAgICAgICAgICAgICA8QXhpcyBheGlzTmFtZT0iZGlfYnV0
dG9uXzkiIHR5cGU9InVuaURpcmVjdGlvbmFsUG9zaXRpdmUiIGRlYWRab25lPSIwLjAiIHNhdHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0
aW9uPg0KICAgICAgICAgICAgPEFjdGlvbiBhY3Rpb25OYW1lPSJNZW51IFRyaWdnZXIgUmlnaHQiPg0KICAgICAgICAgICAgICAgIDxBeGlzIGF4aXNOYW1l
PSJkaV9idXR0b25fOCIgdHlwZT0idW5pRGlyZWN0aW9uYWxQb3NpdGl2ZSIgZGVhZFpvbmU9IjAuMCIgc2F0dXJhdGlvbj0iMS4wIiAvPg0KICAgICAgICAg
ICAgPC9BY3Rpb24+DQoJCQk8QWN0aW9uIGFjdGlvbk5hbWU9Ik1lbnUgU3BlY2lhbCI+DQogICAgICAgICAgICAgIDxBeGlzIGF4aXNOYW1lPSJkaV9idXR0
b25fMTAiIHR5cGU9InVuaURpcmVjdGlvbmFsUG9zaXRpdmUiIGRlYWRab25lPSIwLjAiIHNhdHVyYXRpb249IjEuMCIgLz4NCiAgICAgICAgICAgIDwvQWN0
aW9uPg0KICAgICAgICA8L0FjdGlvbk1hcD4NCiAgICA8L0FjdGlvbk1hcHM+DQo8L0RldmljZT4NCg0K
'@

# ---------------------------------------------------------------------
#  5) Spiele-Auswahl
# ---------------------------------------------------------------------
function Add-ManualGame {
    param([hashtable]$Bag)
    Write-Host ''
    Write-Host '  Pfad zum Spiel-Ordner ODER zum actionmaps-Ordner' -ForegroundColor Yellow
    Write-Host '  (z.B. D:\SteamLibrary\steamapps\common\F1 23) : ' -NoNewline -ForegroundColor Yellow
    $p = (Read-Line).Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host '  [FEHLER] Pfad existiert nicht.' -ForegroundColor Red
        return $false
    }
    if ((Split-Path $p -Leaf) -ieq 'actionmaps') { $p = Split-Path $p -Parent }
    $before = $Bag.Count
    Add-GameCandidate -Bag $Bag -Dir $p -Source 'manuell'
    if ($Bag.Count -eq $before) {
        Write-Host '  [FEHLER] In diesem Ordner gibt es keinen "actionmaps"-Unterordner.' -ForegroundColor Red
        return $false
    }
    Write-Host '  [OK] Spiel hinzugefuegt.' -ForegroundColor Green
    return $true
}

function Select-Games {
    Write-Head 'Schritt 2 - F1-Spiele'
    Write-Host '  Suche installierte F1-Spiele (Steam / EA / Origin / Epic) ...' -ForegroundColor DarkGray

    $bag = @{}
    foreach ($g in (Get-F1Games)) { $bag[$g.Path.ToLower()] = $g }

    while ($true) {
        $games = @($bag.Values | Sort-Object Title)
        Write-Host ''
        if ($games.Count -eq 0) {
            Write-Host '  [!] Kein F1-Spiel automatisch gefunden.' -ForegroundColor Yellow
            if (-not (Add-ManualGame -Bag $bag)) {
                if (-not (Read-YesNo '  Nochmal einen Pfad eingeben?' $true)) { return @() }
            }
            continue
        }

        Write-Host ('  Gefundene Spiele (' + $games.Count + '):') -ForegroundColor White
        for ($i = 0; $i -lt $games.Count; $i++) {
            Write-Host ('   {0,2}) {1,-9} {2}' -f ($i + 1), $games[$i].Title, $games[$i].Path)
            Write-Host ('       Quelle: ' + $games[$i].Source) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host '  Enter = ALLE   |   z.B. "1,3,4" fuer einzelne   |   M = Pfad manuell ergaenzen' -ForegroundColor DarkGray
        Write-Host '  Auswahl: ' -NoNewline -ForegroundColor Yellow
        $raw = (Read-Line).Trim()

        if ($raw -ieq 'm') { [void](Add-ManualGame -Bag $bag); continue }
        if ($raw -eq '') { return $games }

        $sel = @()
        $ok = $true
        foreach ($part in ($raw -split '[,; ]+')) {
            if ($part -eq '') { continue }
            $n = 0
            if ([int]::TryParse($part, [ref]$n) -and $n -ge 1 -and $n -le $games.Count) {
                $sel += $games[$n - 1]
            } else { $ok = $false }
        }
        if ($ok -and $sel.Count -gt 0) { return ($sel | Select-Object -Unique) }
        Write-Host '  Ungueltige Eingabe.' -ForegroundColor Red
    }
}

# ---------------------------------------------------------------------
#  6) Benutzer-Ordner: Dokumente\My Games\F1 20xx
#     (Grafik- und Spieleinstellungen, teils auch Tastenbelegungen)
# ---------------------------------------------------------------------
function Get-F1UserDirs {
    $roots = @()
    try {
        $d = [Environment]::GetFolderPath('MyDocuments')
        if ($d) { $roots += ($d.TrimEnd('\') + '\My Games') }
    } catch { }
    if ($env:USERPROFILE) {
        foreach ($sub in @('Documents\My Games', 'Dokumente\My Games',
                           'OneDrive\Documents\My Games', 'OneDrive\Dokumente\My Games')) {
            $roots += ($env:USERPROFILE.TrimEnd('\') + '\' + $sub)
        }
    }
    $seen = @{}
    $out = @()
    foreach ($r in ($roots | Select-Object -Unique)) {
        try {
            if (-not (Test-Path -LiteralPath $r)) { continue }
            foreach ($d in (Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue)) {
                if ($d.Name -notmatch $script:F1FolderPattern) { continue }
                $key = $d.FullName.ToLower()
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true
                $title = Get-F1Title $d.Name
                if (-not $title) { $title = $d.Name }
                $out += [pscustomobject]@{ Title = $title; Path = $d.FullName }
            }
        } catch { }
    }
    return ($out | Sort-Object Title)
}

function Select-UserGame {
    param([string]$Zweck)
    $dirs = @(Get-F1UserDirs)
    if ($dirs.Count -eq 0) {
        Write-Host ''
        Write-Host '  [!] Unter "Dokumente\My Games" wurde kein F1-Ordner gefunden.' -ForegroundColor Yellow
        Write-Host '      Den legt das Spiel beim ersten Start an.' -ForegroundColor DarkGray
        return $null
    }
    Write-Host ''
    Write-Host ('  Welches Spiel? (' + $Zweck + ')') -ForegroundColor White
    for ($i = 0; $i -lt $dirs.Count; $i++) {
        Write-Host ('   {0,2}) {1,-9} {2}' -f ($i + 1), $dirs[$i].Title, $dirs[$i].Path)
    }
    $sel = Read-Choice '  Auswahl' 1 $dirs.Count
    return $dirs[$sel - 1]
}

# gesichert werden die Einstellungs-Ordner - Savegames bleiben aussen vor
$script:PresetFolders = @('hardwaresettings', 'actionmaps', 'graphicsconfig', 'settings')

function Save-Preset {
    param($UserGame, [string]$Label, [switch]$Quiet)
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $name = ($stamp + '_' + (ConvertTo-SafeName $Label))
    $dest = Join-Path (Join-Path $script:PresetRoot (ConvertTo-SafeName $UserGame.Title)) $name
    $files = 0
    try {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        foreach ($sub in $script:PresetFolders) {
            $src = Join-Path $UserGame.Path $sub
            if (-not (Test-Path -LiteralPath $src)) { continue }
            Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
            $files += @(Get-ChildItem -LiteralPath (Join-Path $dest $sub) -Recurse -File -ErrorAction SilentlyContinue).Count
        }
    } catch {
        Write-Host ('      [FEHLER] ' + $_.Exception.Message) -ForegroundColor Red
        return $null
    }
    if ($files -eq 0) {
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        if (-not $Quiet) {
            Write-Host '  [!] Nichts zu sichern - das Spiel hat noch keine Einstellungen abgelegt.' -ForegroundColor Yellow
        }
        return $null
    }
    Write-Log ('Preset gesichert: ' + $dest + ' (' + $files + ' Dateien)')
    if (-not $Quiet) {
        Write-Host ('  [OK] ' + $files + ' Dateien gesichert') -ForegroundColor Green
        Write-Host ('       ' + $dest) -ForegroundColor DarkGray
    }
    return $dest
}

function Invoke-SavePreset {
    Write-Head 'Einstellungen sichern'
    Write-Host '  Gesichert wird, was das Spiel in "Dokumente\My Games" ablegt:' -ForegroundColor Gray
    Write-Host '  Grafik- und Spieleinstellungen, Force-Feedback, Tastenbelegungen,' -ForegroundColor Gray
    Write-Host '  soweit sie dort als Datei liegen. Savegames bleiben unberuehrt.' -ForegroundColor Gray
    $g = Select-UserGame 'sichern'
    if (-not $g) { return }
    Write-Host ''
    Write-Host '  Kurzer Name fuer das Preset (z.B. mein_setup) : ' -NoNewline -ForegroundColor Yellow
    $label = (Read-Line).Trim()
    if ($label -eq '') { $label = 'preset' }
    Write-Host ''
    [void](Save-Preset -UserGame $g -Label $label)
}

function Invoke-RestorePreset {
    Write-Head 'Preset wiederherstellen'
    $g = Select-UserGame 'wiederherstellen'
    if (-not $g) { return }
    $dir = Join-Path $script:PresetRoot (ConvertTo-SafeName $g.Title)
    $sets = @()
    if (Test-Path -LiteralPath $dir) {
        $sets = @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    }
    if ($sets.Count -eq 0) {
        Write-Host ''
        Write-Host ('  [!] Fuer ' + $g.Title + ' wurde noch kein Preset gesichert.') -ForegroundColor Yellow
        return
    }
    Write-Host ''
    Write-Host '  Gesicherte Presets:' -ForegroundColor White
    for ($i = 0; $i -lt $sets.Count; $i++) {
        $n = @(Get-ChildItem -LiteralPath $sets[$i].FullName -Recurse -File -ErrorAction SilentlyContinue).Count
        Write-Host ('   {0,2}) {1,-34} {2} Dateien' -f ($i + 1), $sets[$i].Name, $n)
    }
    $sel = Read-Choice '  Auswahl' 1 $sets.Count
    $pick = $sets[$sel - 1]

    Write-Host ''
    Write-Host '  Sichere zuerst den aktuellen Stand ...' -ForegroundColor DarkGray
    [void](Save-Preset -UserGame $g -Label 'vor_wiederherstellung' -Quiet)

    $n = 0
    foreach ($sub in (Get-ChildItem -LiteralPath $pick.FullName -Directory -ErrorAction SilentlyContinue)) {
        try {
            Copy-Item -LiteralPath $sub.FullName -Destination $g.Path -Recurse -Force
            $n += @(Get-ChildItem -LiteralPath $sub.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
            Write-Host ('      [OK] ' + $sub.Name) -ForegroundColor Green
        } catch {
            Write-Host ('      [FEHLER] ' + $sub.Name + ': ' + $_.Exception.Message) -ForegroundColor Red
        }
    }
    Write-Log ('Preset wiederhergestellt: ' + $pick.FullName)
    Write-Host ''
    Write-Host ('  ' + $n + ' Dateien zurueckgespielt nach ' + $g.Path) -ForegroundColor Green
    Write-Host '  Der Stand von vorher liegt als Preset "vor_wiederherstellung" daneben.' -ForegroundColor DarkGray
}

function Invoke-Report {
    Write-Head 'Diagnose - was legt das Spiel an?'
    $dirs = @(Get-F1UserDirs)
    $lines = @()
    $lines += ('KERS F1 Mods Installer - Diagnose vom ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    $lines += ''
    if ($dirs.Count -eq 0) {
        $lines += 'Unter "Dokumente\My Games" wurde kein F1-Ordner gefunden.'
    }
    foreach ($d in $dirs) {
        $lines += ('=== ' + $d.Title + ' ===')
        $lines += ('  ' + $d.Path)
        foreach ($f in (Get-ChildItem -LiteralPath $d.Path -File -ErrorAction SilentlyContinue)) {
            $lines += ('  [Datei]   {0,-42} {1,8} Byte   {2}' -f $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd'))
        }
        foreach ($s in (Get-ChildItem -LiteralPath $d.Path -Directory -ErrorAction SilentlyContinue)) {
            $inner = @(Get-ChildItem -LiteralPath $s.FullName -Recurse -File -ErrorAction SilentlyContinue)
            $lines += ('  [Ordner]  {0,-42} {1} Dateien' -f $s.Name, $inner.Count)
            foreach ($f in ($inner | Sort-Object FullName | Select-Object -First 25)) {
                $rel = $f.FullName.Substring($d.Path.Length).TrimStart('\')
                $lines += ('      {0,-52} {1,8} Byte   {2}' -f $rel, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd'))
            }
            if ($inner.Count -gt 25) { $lines += ('      ... und ' + ($inner.Count - 25) + ' weitere') }
        }
        $lines += ''
    }
    foreach ($l in $lines) {
        if ($l -match '^===') { Write-Host ('  ' + $l) -ForegroundColor White }
        elseif ($l -match '\[Ordner\]') { Write-Host ('  ' + $l) -ForegroundColor Cyan }
        else { Write-Host ('  ' + $l) -ForegroundColor Gray }
    }
    $target = $null
    try {
        $desk = [Environment]::GetFolderPath('Desktop')
        if ($desk) {
            $target = Join-Path $desk 'KERS_F1_Diagnose.txt'
            Set-Content -Path $target -Value $lines -Encoding UTF8
        }
    } catch { $target = $null }
    Write-Host ''
    if ($target) {
        Write-Host ('  [OK] Als Datei gespeichert: ' + $target) -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------
#  eingebettetes KERS-Grafik-Preset (presets/f1_25_kers_settings.xml)
# ---------------------------------------------------------------------
$script:PresetXmlB64 = @'
PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiID8+CjxoYXJkd2FyZV9zZXR0aW5nc19jb25maWcgYXBwbHlPT1RCPSJmYWxzZSI+Cgk8Y3B1
IG5hbWU9IiIgcHJvY2Vzc29ycz0iMCIgcHJvY2Vzc29yU3RyaWRlPSIxIiBwcm9jZXNzb3JCaW5kaW5nPSIxIiAvPgoJPGdyYXBoaWNzX2NhcmQgZGV2aWNl
SWQ9IjB4MDAwMCI+CgkJPHJlc29sdXRpb24gd2lkdGg9IjE5MjAiIGhlaWdodD0iMTA4MCIgZGlzcGxheU1vZGU9IjIiIHZzeW5jPSJmYWxzZSIgdnN5bmNJ
bnRlcnZhbD0iYXV0byIgZnJhbWVSYXRlTGltaXRlckVuYWJsZWQ9ImZhbHNlIiBmcmFtZVJhdGVMaW1pdGVyVmFsdWU9IjAiPgoJCQk8cmVmcmVzaFJhdGUg
bnVtZXJhdG9yPSI2MDAwMCIgZGVub21pbmF0b3I9IjEwMDAiIC8+CgkJCTx3aW5kb3dQb3NpdGlvbiB4PSIwIiB5PSIwIiAvPgoJCQk8b3V0cHV0TW9uaXRv
ciBpbmRleD0iMSIgLz4KCQkJPGFzcGVjdFJhdGlvIGF1dG89InRydWUiIHdpZHRoPSIwIiBoZWlnaHQ9IjAiIC8+CgkJCTxoZHIgbW9kZT0iMCIgcGVha05p
dHM9IjEwMDAiIC8+CgkJPC9yZXNvbHV0aW9uPgoJPC9ncmFwaGljc19jYXJkPgoJPG1vdGlvbj4KCQk8ZGJveCBlbmFibGVkPSJmYWxzZSIgLz4KCQk8dWRw
IGVuYWJsZWQ9InRydWUiIGJyb2FkY2FzdD0iZmFsc2UiIGlwPSIxMjcuMC4wLjEiIHBvcnQ9IjIyMDI1IiBzZW5kUmF0ZT0iNjAiIGZvcm1hdD0iMjAyNiIg
eW91clRlbGVtZXRyeT0icmVzdHJpY3RlZCIgb25saW5lTmFtZXM9Im9uIiAvPgoJPC9tb3Rpb24+Cgk8YW50aWFsaWFzaW5nIHRhYT0iZmFsc2UiIGNhcz0i
MSIgZGxzcz0idHJ1ZSIgZnNyMz0iMCIgeGVzcz0iZmFsc2UiIC8+Cgk8YWFfcXVhbGl0eSB2YWx1ZT0iMyIgLz4KCTxhYV9zaGFycG5lc3MgdmFsdWU9IjAu
NSIgLz4KCTxmcmFtZV9nZW4gbW9kZT0iMCIgLz4KCTxtdWx0aV9mcmFtZV9nZW4gdmFsdWU9IjAiIC8+Cgk8ZHluYW1pY3Jlc29sdXRpb25fZW5hYmxlZCB2
YWx1ZT0iZmFsc2UiIC8+Cgk8ZHluYW1pY3Jlc29sdXRpb25fdGFyZ2V0X2ZwcyB2YWx1ZT0iMTIwIiAvPgoJPGR5bmFtaWNyZXNvbHV0aW9uX3Byb2ZpbGUg
ZGVsdGFEb3duPSIwLjAyIiBwZXJjZW50YWdlRG93bj0iMC45NzUiIGRlbHRhVXA9IjAuMDEiIHBlcmNlbnRhZ2VVcD0iMC45MjUiIGFscGhhPSIwLjk1IiAv
PgoJPGR5bmFtaWNyZXNvbHV0aW9uX21pbl9zY2FsZSB2YWx1ZT0iMC45MDAwMDAiIC8+Cgk8c3NhbyBlbmFibGVkPSJ0cnVlIiBhbGdvcml0aG09IjMiIC8+
Cgk8c3NydCBlbmFibGVkPSJ0cnVlIiBxdWFsaXR5PSIyIiAvPgoJPHRleHR1cmVfc3RyZWFtaW5nIHNpemVJbk1pQj0iMTUzNiIgdGV4ZWxEZW5zaXR5Qmlh
cz0iMC4wIiBjb25jdXJyZW50VGV4dHVyZVN3YXBzPSIxIiAvPgoJPGxlZF9kaXNwbGF5IGZhbmF0ZWNOYXRpdmVTdXBwb3J0PSJmYWxzZSIgc2xpUHJvTmF0
aXZlU3VwcG9ydD0iZmFsc2UiIHNsaVByb0ZvcmNlQnJpZ2h0bmVzcz0iMTI3IiB3b290aW5nUkdCRW5hYmxlZD0iZmFsc2UiIC8+Cgk8YW5pc290cm9waWNf
ZmlsdGVyIGxldmVsPSIxNiIgLz4KCTxsaWdodGluZyBxdWFsaXR5PSIxIiB2b2x1bWV0cmljRm9nPSJ0cnVlIiB2b2x1bWV0cmljRm9nTWFwV2lkdGg9IjUx
MiIgdm9sdW1ldHJpY0ZvZ01hcEhlaWdodD0iMjU2IiAvPgoJPHBvc3Rwcm9jZXNzIG1vdGlvbkJsdXI9InRydWUiIGdvZFJheXM9ImZhbHNlIiBkZXB0aE9m
RmllbGQ9ImZhbHNlIiBsZW5zU3RyZWFrPSJmYWxzZSIgbGVuc0ZsYXJlPSJmYWxzZSIgYmxvb209ImZhbHNlIiBtb3Rpb25CbHVyVjI9ImZhbHNlIiAvPgoJ
PHNoYWRvd3MgZW5hYmxlZD0idHJ1ZSIgc2t5U2hhZG93TWFwU2l6ZT0iMTAyNCIgc2t5U2hhZG93Q2FzY2FkZUNvdW50PSI0IiBza3lTaGFkb3dMb3dMb2Q9
ImZhbHNlIiB3b3JsZFNoYWRvd01hcFNpemU9IjEwMjQiIHNreVNoYWRvd01hcDMyQml0cz0iZmFsc2UiIG5pZ2h0U2hhZG93TWFwU2l6ZT0iMTAyNCIgbmln
aHRTaGFkb3dDaGFyYWN0ZXJDYXN0PSJ0cnVlIiBuaWdodFNoYWRvd1NvdXJjZUNvdW50PSI0IiBzYW1wbGluZz0iMSIgc3BvdFNoYWRvd01hcFNpemU9IjEw
MjQiIHNwb3RTaGFkb3dTYW1wbGluZz0iMSIgY3Jvd2RJblNoYWRvd3M9ImZhbHNlIiAvPgoJPHBhcnRpY2xlcyBlbmFibGVkPSJ0cnVlIiBkaXN0YW5jZVNj
YWxlPSIxLjAiIHJhdGU9IjEuMCIgaGlnaD0idHJ1ZSIgLz4KCTxjcm93ZCBkaXN0YW5jZVNjYWxlPSIzLjAiIGJpbGxib2FyZERpc3RhbmNlPSIxNTAwIiAv
PgoJPHZlaGljbGVfcmVmbGVjdGlvbnMgZW52TWFwU2NhbGU9IjAuMjUiIGVudk1hcFVwZGF0ZU1vZGU9ImFsdGVybmF0ZSIgZW52TWFwUmVuZGVyTW9kZT0i
Y2FycyIgY3ViZU1hcEVuYWJsZWQ9InRydWUiIGN1YmVNYXBTY2FsZT0iMC41IiBjdWJlTWFwVXBkYXRlTW9kZT0ib25lRmFjZVBlckZyYW1lIiAvPgoJPG1p
cnJvcnMgbWlycm9yc1VwZGF0ZU1vZGU9ImFsdGVybmF0ZSIgbWlycm9yc1JlbmRlck1vZGU9ImNhcnMiIHRyZWVzSW5NaXJyb3JzPSJ0cnVlIiBjcm93ZElu
TWlycm9ycz0iZmFsc2UiIGhpZ2hEZXRhaWxNaXJyb3JzPSJmYWxzZSIgaGlnaERldGFpbFR5cmVzQW5kQ2FyPSJmYWxzZSIgcGFydGljbGVzSW5NaXJyb3Jz
PSJmYWxzZSIgLz4KCTx3ZWF0aGVyX2VmZmVjdHMgcmFpblNwbGFzaGVzPSJ0cnVlIiByYWluU2hlZXRzPSJmYWxzZSIgcmFpbkJlYWRzPSJmYWxzZSIgcmFp
bkhpZ2g9ImZhbHNlIiB0cmFja0hlYXRIYXplPSJ0cnVlIiBwbGFuYXJSZWZsZWN0aW9uc0VuYWJsZWQ9InRydWUiIHBsYW5hclJlZmxlY3Rpb25zSFFFbmFi
bGVkPSJmYWxzZSIgcGxhbmFyUmVmbGVjdGlvbnNSYW5nZVNjYWxlPSIxLjAiIHBsYW5hclJlZmxlY3Rpb25zUlRTY2FsZT0iMC41IiBwbGFuYXJSZWZsZWN0
aW9uc01pcFRhaWxCbHVyPSJ0cnVlIiBwcm9jZWR1cmFsQ2xvdWRSVFNjYWxlPSIxLjAiIHByb2NlZHVyYWxDbG91ZFRpbGluZz0iNyIgcHJvY2VkdXJhbENs
b3VkUXVhbGl0eT0iMSIgLz4KCTxncm91bmRfY292ZXIgZW5hYmxlZD0idHJ1ZSIgZ3Jhc3NGbGF0dGVuaW5nPSJmYWxzZSIgZHJhd0Rpc3RhbmNlPSI2MC4w
IiBtZXNoZXM9ImZhbHNlIiAvPgoJPHRyZWVzIHVzZUxPRDA9ImZhbHNlIiBkaXN0YW5jZVNjYWxlPSIxLjAiIC8+Cgk8aGFpciBlbmFibGVkPSJmYWxzZSIg
Lz4KCTxza2lkbWFya3MgZW5hYmxlZD0idHJ1ZSIgcGFyYWxsYXg9ImZhbHNlIiAvPgoJPHNraWRtYXJrc19ibGVuZGluZyBlbmFibGVkPSJmYWxzZSIgLz4K
CTxhdWRpbyBhdWRpb1VwZGF0ZVJhdGU9IjIiIG51bV9qb2Jfd29ya2VyX3RocmVhZHM9IjEyIiAvPgoJPGFzeW5jX2NvbXB1dGUgZW5hYmxlZD0idHJ1ZSIg
Lz4KCTxjc19jdWxsaW5nIGVuYWJsZWQ9ImZhbHNlIiAvPgoJPHZlbmRvcl9zaGFkZXJfcGFjayBlbmFibGVkPSJ0cnVlIiAvPgoJPHJlcGxheV9kaXJlY3Rv
cnkgcGF0aD0iIiAvPgoJPHJ0X3BhdGh0cmFjZSBlbmFibGVkPSJmYWxzZSIgLz4KCTxydF9yYXlfcmVjb25zdHJ1Y3Rpb24gZW5hYmxlZD0iZmFsc2UiIC8+
Cgk8cnRfc2hhZG93cyBlbmFibGVkPSJmYWxzZSIgLz4KCTxydF9yZWZsZWN0aW9ucyBlbmFibGVkPSJmYWxzZSIgLz4KCTxydF90cmFuc3BhcmVudF9yZWZs
ZWN0aW9ucyBlbmFibGVkPSJmYWxzZSIgLz4KCTxydF9hbyBlbmFibGVkPSJmYWxzZSIgLz4KCTxydF9kZGdpIGVuYWJsZWQ9ImZhbHNlIiAvPgoJPHJ0X3Zl
cnNpb24gdmVyc2lvbj0iMCIgLz4KCTx2cnMgZW5hYmxlZD0idHJ1ZSIgLz4KCTxyZWZsZXggbW9kZT0iMiIgLz4KCTxzZXIgZW5hYmxlZD0iZmFsc2UiIC8+
Cgk8Y2EgZW5hYmxlZD0iZmFsc2UiIC8+CjwvaGFyZHdhcmVfc2V0dGluZ3NfY29uZmlnPg==
'@

# ---------------------------------------------------------------------
#  KERS-Grafik-Preset (aus F1 25 / F1 26)
#
#  Uebernommen werden nur Werte, die es im Zielspiel auch wirklich gibt.
#  Alles Hardwareabhaengige bleibt so, wie es auf diesem Rechner steht:
#  CPU, Aufloesung/Monitor/HDR/FPS-Limit, GPU-ID, Texturspeicher,
#  Audio-Threads, LED-Displays und der Replay-Ordner.
# ---------------------------------------------------------------------
$script:KeepNodes = @(
    '/hardware_settings_config/cpu',
    '/hardware_settings_config/graphics_card/resolution',
    '/hardware_settings_config/led_display',
    '/hardware_settings_config/replay_directory'
)
$script:KeepAttrs = @{
    '/hardware_settings_config/graphics_card'     = @('deviceId')
    '/hardware_settings_config/audio'             = @('num_job_worker_threads')
    '/hardware_settings_config/texture_streaming' = @('sizeInMiB')
    '/hardware_settings_config/motion/udp'        = @('format')
}

# Upscaling-Stufe: 0=Ultra Performance, 1=Performance, 2=Ausgewogen,
# 3=Qualitaet, 4=Ultra Qualitaet
$script:UpscaleBalanced = '2'

function Get-KersPreset {
    $b64 = ($script:PresetXmlB64 -replace '\s', '')
    $text = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.LoadXml($text)
    return $doc
}

function New-MergeLog {
    return [pscustomobject]@{
        Set     = 0
        Kept    = 0
        Skipped = 0
        Changes = (New-Object System.Collections.ArrayList)
    }
}

function Test-KeepNode {
    param([string]$Path)
    foreach ($k in $script:KeepNodes) {
        if ($Path -eq $k -or $Path.StartsWith($k + '/')) { return $true }
    }
    return $false
}

function Set-AttrIfPresent {
    param($Node, [string]$Name, [string]$Value, $Log, [string]$Path)
    if ($null -eq $Node) { return }
    $a = $Node.get_Attributes()[$Name]
    if ($null -eq $a) { $Log.Skipped++; return }      # kennt dieses Spiel nicht
    $old = $a.get_Value()
    if ($old -eq $Value) { return }
    [void]$Log.Changes.Add(('{0}/@{1}:  {2}  ->  {3}' -f $Path.TrimStart('/'), $Name, $old, $Value))
    $a.set_Value($Value)
    $Log.Set++
}

function Merge-XmlValues {
    param($Src, $Dst, [string]$Path, $Log)
    # get_Name() statt .Name: PowerShell blendet bei XML-Elementen sonst
    # gleichnamige Attribute ein (z.B. <cpu name="..."> -> .Name = "...")
    foreach ($a in @($Src.get_Attributes())) {
        $an = $a.get_Name()
        $keep = $script:KeepAttrs[$Path]
        if ($keep -and ($keep -contains $an)) { $Log.Kept++; continue }
        Set-AttrIfPresent -Node $Dst -Name $an -Value $a.get_Value() -Log $Log -Path $Path
    }
    foreach ($child in @($Src.get_ChildNodes())) {
        if ($child.get_NodeType() -ne [System.Xml.XmlNodeType]::Element) { continue }
        $cn = $child.get_Name()
        $cp = $Path + '/' + $cn
        if (Test-KeepNode $cp) { $Log.Kept++; continue }
        $dstChild = $Dst.SelectSingleNode($cn)
        if ($null -eq $dstChild) { $Log.Skipped++; continue }
        Merge-XmlValues -Src $child -Dst $dstChild -Path $cp -Log $Log
    }
}

function Get-GpuName {
    $names = @()
    try {
        $names = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
                   ForEach-Object { [string]$_.Name })
    } catch { }
    $names = @($names | Where-Object { $_ -and ($_ -notmatch 'Basic Display|Remote Display|Virtual|Parsec|Citrix|Meta ') })
    if ($names.Count -eq 0) { return '' }
    $pref = @($names | Where-Object { $_ -match 'RTX|GTX|Radeon RX|Radeon Pro|Arc' })
    if ($pref.Count -gt 0) { return $pref[0] }
    return $names[0]
}

function Set-UpscalingForGpu {
    param($Doc, [string]$Gpu, $Log)
    $root = $Doc.DocumentElement
    $pAA = '/hardware_settings_config/antialiasing'
    if ($Gpu -match 'RTX') { return $false }

    # keine RTX -> DLSS aus, FSR an, Stufe "ausgewogen"
    $aa = $root.SelectSingleNode('antialiasing')
    if ($null -eq $aa -or $null -eq $aa.get_Attributes()['fsr3']) {
        # aeltere Spiele kennen kein FSR - dann nicht am AA herumdrehen
        Write-Host '      [i] Dieses Spiel kennt kein FSR - Kantenglaettung bleibt wie im Preset.' -ForegroundColor DarkYellow
        return $false
    }
    Set-AttrIfPresent -Node $aa -Name 'dlss' -Value 'false' -Log $Log -Path $pAA
    Set-AttrIfPresent -Node $aa -Name 'xess' -Value 'false' -Log $Log -Path $pAA
    Set-AttrIfPresent -Node $aa -Name 'taa'  -Value 'false' -Log $Log -Path $pAA
    Set-AttrIfPresent -Node $aa -Name 'fsr3' -Value '1'     -Log $Log -Path $pAA
    Set-AttrIfPresent -Node ($root.SelectSingleNode('aa_quality')) -Name 'value' `
                      -Value $script:UpscaleBalanced -Log $Log -Path '/hardware_settings_config/aa_quality'

    if ($Gpu -notmatch 'NVIDIA|GeForce|GTX') {
        # laeuft nur auf NVIDIA - auf AMD/Intel sonst nutzlos eingeschaltet
        Set-AttrIfPresent -Node ($root.SelectSingleNode('reflex')) -Name 'mode' -Value '0' -Log $Log -Path '/hardware_settings_config/reflex'
        Set-AttrIfPresent -Node ($root.SelectSingleNode('ser')) -Name 'enabled' -Value 'false' -Log $Log -Path '/hardware_settings_config/ser'
        Set-AttrIfPresent -Node ($root.SelectSingleNode('rt_ray_reconstruction')) -Name 'enabled' -Value 'false' -Log $Log -Path '/hardware_settings_config/rt_ray_reconstruction'
    }
    return $true
}

function Set-AaFallback {
    # Das Preset laesst TAA aus, weil DLSS laeuft. Kennt ein Spiel weder
    # DLSS noch FSR noch XeSS, waere danach gar keine Kantenglaettung an -
    # dann TAA wieder einschalten.
    param($Doc, $Log)
    $aa = $Doc.DocumentElement.SelectSingleNode('antialiasing')
    if ($null -eq $aa) { return }
    $attrs = $aa.get_Attributes()
    $on = $false
    foreach ($n in @('dlss', 'xess')) {
        $a = $attrs[$n]
        if ($a -and ($a.get_Value() -eq 'true')) { $on = $true }
    }
    $f = $attrs['fsr3']
    if ($f -and ($f.get_Value() -ne '0') -and ($f.get_Value() -ne 'false')) { $on = $true }
    if (-not $on) {
        Set-AttrIfPresent -Node $aa -Name 'taa' -Value 'true' -Log $Log -Path '/hardware_settings_config/antialiasing'
    }
}

function Set-FrameGenOff {
    # Frame Generation bleibt aus - unabhaengig von Preset und Grafikkarte
    param($Doc, $Log)
    $root = $Doc.DocumentElement
    Set-AttrIfPresent -Node ($root.SelectSingleNode('frame_gen')) -Name 'mode' -Value '0' `
                      -Log $Log -Path '/hardware_settings_config/frame_gen'
    Set-AttrIfPresent -Node ($root.SelectSingleNode('multi_frame_gen')) -Name 'value' -Value '0' `
                      -Log $Log -Path '/hardware_settings_config/multi_frame_gen'
}

function Set-UdpOn {
    param($Doc, $Log)
    $udp = $Doc.DocumentElement.SelectSingleNode('motion/udp')
    if ($null -eq $udp) {
        Write-Host '      [i] Dieses Spiel kennt keine UDP-Telemetrie - uebersprungen.' -ForegroundColor DarkYellow
        return
    }
    $p = '/hardware_settings_config/motion/udp'
    Set-AttrIfPresent -Node $udp -Name 'enabled'     -Value 'true' -Log $Log -Path $p
    Set-AttrIfPresent -Node $udp -Name 'onlineNames' -Value 'on'   -Log $Log -Path $p
}

function Save-XmlFile {
    param($Doc, [string]$Path)
    # BOM-Zustand der Originaldatei beibehalten - das Spiel bekommt die
    # Datei so zurueck, wie sein Parser sie kennt
    $bom = $false
    try {
        $b = [IO.File]::ReadAllBytes($Path)
        if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $bom = $true }
    } catch { }
    $set = New-Object System.Xml.XmlWriterSettings
    $set.Encoding = New-Object System.Text.UTF8Encoding($bom)
    $set.Indent = $false
    $set.NewLineHandling = [System.Xml.NewLineHandling]::None
    $w = $null
    try {
        $w = [System.Xml.XmlWriter]::Create($Path, $set)
        $Doc.Save($w)
    } finally {
        if ($w) { $w.Close() }
    }
}

function Invoke-ApplyPreset {
    Write-Head 'KERS-Grafik-Preset anwenden'
    Write-Host '  Qualitaets-Einstellungen kommen aus dem Preset, alles Hardware-' -ForegroundColor Gray
    Write-Host '  abhaengige bleibt von dir: CPU, Aufloesung, Monitor, HDR, FPS-Limit,' -ForegroundColor Gray
    Write-Host '  Texturspeicher, Audio-Threads, LED-Display, Replay-Ordner.' -ForegroundColor Gray

    $gpu = Get-GpuName
    Write-Host ''
    if ($gpu) {
        Write-Host ('  Grafikkarte : ' + $gpu) -ForegroundColor White
    } else {
        Write-Host '  Grafikkarte : nicht erkannt - wird wie "keine RTX" behandelt' -ForegroundColor Yellow
    }
    if ($gpu -match 'RTX') {
        Write-Host '  Upscaling   : DLSS bleibt an (Preset-Einstellung)' -ForegroundColor DarkGray
    } else {
        Write-Host '  Upscaling   : keine RTX -> FSR an, Stufe "ausgewogen"' -ForegroundColor DarkGray
    }
    Write-Host '  Ausserdem   : Frame Generation aus, UDP-Telemetrie an, Online-Namen an' -ForegroundColor DarkGray

    $g = Select-UserGame 'Preset anwenden'
    if (-not $g) { return }

    $file = Join-Path $g.Path 'hardwaresettings\hardware_settings_config.xml'
    if (-not (Test-Path -LiteralPath $file)) {
        Write-Host ''
        Write-Host ('  [!] ' + $file) -ForegroundColor Yellow
        Write-Host '      gibt es nicht. Das Spiel muss einmal gestartet worden sein.' -ForegroundColor DarkGray
        return
    }

    Write-Host ''
    Write-Host '  Sichere den aktuellen Stand ...' -ForegroundColor DarkGray
    [void](Save-Preset -UserGame $g -Label 'vor_kers_preset' -Quiet)

    try {
        $preset = Get-KersPreset
        $target = New-Object System.Xml.XmlDocument
        $target.PreserveWhitespace = $true
        $target.Load($file)
    } catch {
        Write-Host ('  [FEHLER] XML konnte nicht gelesen werden: ' + $_.Exception.Message) -ForegroundColor Red
        return
    }

    $log = New-MergeLog
    Merge-XmlValues -Src $preset.DocumentElement -Dst $target.DocumentElement `
                    -Path '/hardware_settings_config' -Log $log
    [void](Set-UpscalingForGpu -Doc $target -Gpu $gpu -Log $log)
    Set-AaFallback -Doc $target -Log $log
    Set-FrameGenOff -Doc $target -Log $log
    Set-UdpOn -Doc $target -Log $log

    try {
        Save-XmlFile -Doc $target -Path $file
    } catch {
        Write-Host ('  [FEHLER] Schreiben fehlgeschlagen: ' + $_.Exception.Message) -ForegroundColor Red
        return
    }
    Write-Log ('Preset angewendet: ' + $file + ' (' + $log.Set + ' Werte, GPU: ' + $gpu + ')')

    Write-Host ''
    $show = [Math]::Min($log.Changes.Count, 25)
    for ($i = 0; $i -lt $show; $i++) {
        Write-Host ('      ' + $log.Changes[$i]) -ForegroundColor DarkGray
    }
    if ($log.Changes.Count -gt $show) {
        Write-Host ('      ... und ' + ($log.Changes.Count - $show) + ' weitere') -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host ('  [OK] ' + $log.Set + ' Werte gesetzt, ' + $log.Kept + ' vom Rechner behalten, ' +
                $log.Skipped + ' kennt dieses Spiel nicht.') -ForegroundColor Green
    Write-Host ('       ' + $file) -ForegroundColor DarkGray
    Write-Host '  Rueckgaengig: Menuepunkt 6, Preset "vor_kers_preset".' -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------
#  8) Hauptablauf
# ---------------------------------------------------------------------
function Invoke-Main {
    Show-Banner

    if (-not (Test-Admin)) {
        Write-Host ''
        Write-Host '  [i] Ohne Administrator-Rechte kann in "Program Files" nicht' -ForegroundColor Yellow
        Write-Host '      geschrieben werden.' -ForegroundColor Yellow
        if (Read-YesNo '  Jetzt als Administrator neu starten?' $true) {
            if (Invoke-Elevate) { return 0 }
            Write-Host '  [!] Neustart als Admin fehlgeschlagen - mache normal weiter.' -ForegroundColor Red
        }
    }

    Write-Host ''
    Write-Host '   MOZA Wheel-Fix' -ForegroundColor DarkGray
    Write-Host '   1) installieren' -ForegroundColor White
    Write-Host '   2) deinstallieren (Originalzustand)' -ForegroundColor White
    Write-Host '   3) nur testen (nichts schreiben)' -ForegroundColor White
    Write-Host '' 
    Write-Host '   Einstellungen (Dokumente\My Games)' -ForegroundColor DarkGray
    Write-Host '   4) KERS-Grafik-Preset anwenden (FSR/DLSS je GPU, UDP an)' -ForegroundColor White
    Write-Host '   5) eigene Einstellungen sichern' -ForegroundColor White
    Write-Host '   6) gesichertes Preset wiederherstellen' -ForegroundColor White
    Write-Host '   7) Diagnose: was legt das Spiel an?' -ForegroundColor White
    Write-Host ''
    Write-Host '   8) Beenden' -ForegroundColor White
    $mode = Read-Choice '  Auswahl' 1 8 1
    if ($mode -eq 8) { return 0 }

    if ($mode -eq 4) { Invoke-ApplyPreset;   return 0 }
    if ($mode -eq 5) { Invoke-SavePreset;    return 0 }
    if ($mode -eq 6) { Invoke-RestorePreset; return 0 }
    if ($mode -eq 7) { Invoke-Report;        return 0 }

    if ($mode -eq 2) {
        $games = @(Select-Games)
        if ($games.Count -eq 0) { return 1 }
        Invoke-Uninstall -Games $games
        return 0
    }

    $base = Select-MozaBase
    # fester Name in der Geraeteliste des Spiels - umbenennen geht im Spiel
    $modName = ConvertTo-SafeName ('KERS_' + $base.Slug.ToUpper() + '_F1_MOD')
    Write-Host ''
    Write-Host ('  Wheelbase    : ' + $base.Label) -ForegroundColor White
    Write-Host ('  GUID         : ' + $base.Guid) -ForegroundColor DarkGray
    Write-Host ('  Name im Spiel: ' + $modName) -ForegroundColor DarkGray
    Write-Host ('  Datei        : ' + $modName + '.xml') -ForegroundColor DarkGray

    $games = @(Select-Games)
    if ($games.Count -eq 0) {
        Write-Host ''
        Write-Host '  Nichts zu tun.' -ForegroundColor Yellow
        return 1
    }

    $emuProfile = Select-EmulationProfile -Games $games

    Write-Head 'Installation'
    $results = @()
    foreach ($g in $games) {
        Write-Host ''
        Write-Host ('  ' + $g.Title + '   ' + $g.Path) -ForegroundColor White
        if ($mode -eq 3) {
            $results += (Install-ToGame -Game $g -Base $base -Source $emuProfile -ProfileName $modName -DisplayName $modName -DryRun)
        } else {
            $results += (Install-ToGame -Game $g -Base $base -Source $emuProfile -ProfileName $modName -DisplayName $modName)
        }
    }

    if ($mode -ne 3) { Save-Manifest -Results $results }

    Write-Head 'Ergebnis'
    foreach ($r in $results) {
        $col = 'Green'
        if ($r.Status -eq 'Fehler') { $col = 'Red' }
        if ($r.Status -eq 'Test')   { $col = 'DarkGray' }
        Write-Host ('   {0,-9} {1,-7} Name: {2,-20} emuliert: {3}' -f $r.Game, $r.Status, $r.Shown, $r.Emulates) -ForegroundColor $col
    }

    $bad = @($results | Where-Object { $_.Status -eq 'Fehler' })
    Write-Host ''
    if ($bad.Count -gt 0) {
        Write-Host '  [!] Mindestens ein Spiel konnte nicht beschrieben werden.' -ForegroundColor Red
        Write-Host '      Tipp: Installer als Administrator starten (Rechtsklick -> Als Administrator ausfuehren).' -ForegroundColor Yellow
    } elseif ($mode -eq 3) {
        Write-Host '  Testlauf beendet - es wurde nichts veraendert.' -ForegroundColor Gray
    } else {
        Write-Host '  Fertig. Im Spiel unter Einstellungen -> Steuerung erscheint die' -ForegroundColor Green
        Write-Host ('  Base als "' + $modName + '" - dort auswaehlen und Belegung pruefen.') -ForegroundColor Green
    }
    Write-Host ('  Log: ' + $script:LogFile) -ForegroundColor DarkGray
    return 0
}

$exit = 0
try {
    $exit = Invoke-Main
} catch {
    Write-Host ''
    Write-Host ('  [FEHLER] ' + $_.Exception.Message) -ForegroundColor Red
    Write-Log ('ABBRUCH: ' + $_.Exception.ToString())
    $exit = 1
}

Write-Host ''
Write-Host '  Beliebige Taste zum Beenden ...' -ForegroundColor DarkGray
try { [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Read-Host | Out-Null }
exit $exit
