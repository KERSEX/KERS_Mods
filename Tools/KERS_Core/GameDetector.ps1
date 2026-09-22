# =====================================================================
#  KERS Core - Spiele finden
#  Datengetrieben ueber games.json: Steam-Bibliotheken, Epic-Manifeste,
#  Registry, Standardordner auf allen festen Laufwerken, dazu die
#  Benutzerordner (Dokumente, AppData).
#  Feste Laufwerksbuchstaben werden nie vorausgesetzt.
# =====================================================================

function Get-KersFixedDrives {
    $drives = @()
    try {
        $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue |
                    ForEach-Object { [string]$_.DeviceID })
    } catch { }
    if ($drives.Count -eq 0) {
        try {
            $drives = @([IO.DriveInfo]::GetDrives() |
                        Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } |
                        ForEach-Object { $_.Name.TrimEnd('\') })
        } catch { }
    }
    return ($drives | Where-Object { $_ } | Select-Object -Unique)
}

function Get-KersSteamLibraries {
    $libs = @()
    $steam = $null
    foreach ($rk in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            if (-not (Test-Path $rk)) { continue }
            $p = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
            if ($p.SteamPath)        { $steam = [string]$p.SteamPath }
            elseif ($p.InstallPath)  { $steam = [string]$p.InstallPath }
            if ($steam) { break }
        } catch { }
    }
    if ($steam) {
        $steam = $steam.Replace('/', '\').TrimEnd('\')
        $libs += $steam
        $vdf = $steam + '\steamapps\libraryfolders.vdf'
        try {
            if (Test-Path -LiteralPath $vdf) {
                foreach ($line in (Get-Content -LiteralPath $vdf -ErrorAction SilentlyContinue)) {
                    $m = [regex]::Match($line, '"path"\s+"([^"]+)"')
                    if ($m.Success) { $libs += $m.Groups[1].Value.Replace('\\', '\').TrimEnd('\') }
                }
            }
        } catch { }
    }
    # haeufige Bibliotheken ohne Steam-Registry (portable Installationen)
    foreach ($d in (Get-KersFixedDrives)) {
        $libs += ($d.TrimEnd('\') + '\SteamLibrary')
        $libs += ($d.TrimEnd('\') + '\Steam')
        $libs += ($d.TrimEnd('\') + '\Games\SteamLibrary')
    }
    return ($libs | Select-Object -Unique)
}

function Get-KersEpicDirs {
    $dirs = @()
    if (-not $env:ProgramData) { return $dirs }
    $mf = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    try {
        if (Test-Path -LiteralPath $mf) {
            foreach ($f in (Get-ChildItem -LiteralPath $mf -Filter *.item -File -ErrorAction SilentlyContinue)) {
                try {
                    $j = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                    if ($j.InstallLocation) { $dirs += [string]$j.InstallLocation }
                } catch { }
            }
        }
    } catch { }
    return ($dirs | Select-Object -Unique)
}

function Get-KersRegistryDirs {
    param([string[]]$NamePatterns)
    $dirs = @()
    if (-not $NamePatterns -or $NamePatterns.Count -eq 0) { return $dirs }
    foreach ($r in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
        try {
            if (-not (Test-Path $r)) { continue }
            foreach ($k in (Get-ChildItem -Path $r -ErrorAction SilentlyContinue)) {
                try {
                    $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                    $dn = [string]$p.DisplayName
                    if (-not $dn -or -not $p.InstallLocation) { continue }
                    foreach ($pat in $NamePatterns) {
                        if ($dn -match $pat) { $dirs += [string]$p.InstallLocation; break }
                    }
                } catch { }
            }
        } catch { }
    }
    return ($dirs | Select-Object -Unique)
}

function Expand-KersPath {
    # %DOCS%, %USERPROFILE%, %LOCALAPPDATA%, %APPDATA%, %PROGRAMDATA%
    param([string]$Template)
    $docs = ''
    try { $docs = [Environment]::GetFolderPath('MyDocuments') } catch { }
    if (-not $docs -and $env:USERPROFILE) { $docs = $env:USERPROFILE.TrimEnd('\') + '\Documents' }
    $map = @{
        '%DOCS%'        = $docs
        '%USERPROFILE%' = $env:USERPROFILE
        '%LOCALAPPDATA%'= $env:LOCALAPPDATA
        '%APPDATA%'     = $env:APPDATA
        '%PROGRAMDATA%' = $env:ProgramData
    }
    $out = $Template
    foreach ($k in $map.Keys) {
        $v = $map[$k]
        if ($out -like ('*' + $k + '*')) {
            if (-not $v) { return $null }
            $out = $out.Replace($k, $v.TrimEnd('\'))
        }
    }
    return $out
}

function Test-KersFolderMatch {
    param([string]$Name, $Install)
    if ($Install.folderNames) {
        foreach ($n in $Install.folderNames) { if ($Name -ieq $n) { return $true } }
    }
    if ($Install.folderPattern) {
        if ($Name -match $Install.folderPattern) { return $true }
    }
    return $false
}

function Test-KersMarker {
    param([string]$Path, [string]$Marker)
    if (-not $Marker) { return $true }
    return (Test-Path -LiteralPath (Join-Path $Path $Marker))
}

function Add-KersInstall {
    param([hashtable]$Bag, [string]$Path, [string]$Source, $Def)
    if (-not $Path) { return }
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return }
        $full = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
        $leaf = Split-Path $full -Leaf
        if (-not (Test-KersFolderMatch $leaf $Def.install)) { return }
        if (-not (Test-KersMarker $full $Def.install.marker)) { return }
        $key = $full.ToLower()
        if ($Bag.ContainsKey($key)) { return }
        $Bag[$key] = [pscustomobject]@{ Title = $leaf; Path = $full; Source = $Source }
    } catch { }
}

function Find-KersInstalls {
    param($Def)
    $bag = @{}
    if (-not $Def.install) { return @() }

    foreach ($lib in (Get-KersSteamLibraries)) {
        $common = $lib.TrimEnd('\') + '\steamapps\common'
        try {
            if (-not (Test-Path -LiteralPath $common)) { continue }
            foreach ($d in (Get-ChildItem -LiteralPath $common -Directory -ErrorAction SilentlyContinue)) {
                Add-KersInstall -Bag $bag -Path $d.FullName -Source 'Steam' -Def $Def
            }
        } catch { }
    }

    $roots = @()
    foreach ($d in (Get-KersFixedDrives)) {
        $b = $d.TrimEnd('\')
        foreach ($sub in @('Program Files\EA Games', 'Program Files (x86)\Origin Games',
                           'Program Files\Epic Games', 'Program Files (x86)\Epic Games',
                           'Program Files', 'Program Files (x86)',
                           'EA Games', 'Origin Games', 'Epic Games', 'Games', 'GOG Games')) {
            $roots += ($b + '\' + $sub)
        }
    }
    foreach ($root in ($roots | Select-Object -Unique)) {
        try {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
                Add-KersInstall -Bag $bag -Path $d.FullName -Source 'Ordner-Scan' -Def $Def
            }
        } catch { }
    }

    foreach ($d in (Get-KersEpicDirs))                                  { Add-KersInstall -Bag $bag -Path $d -Source 'Epic' -Def $Def }
    foreach ($d in (Get-KersRegistryDirs -NamePatterns $Def.install.registryNames)) { Add-KersInstall -Bag $bag -Path $d -Source 'Registry' -Def $Def }

    return @($bag.Values)
}

function Find-KersUserDirs {
    param($Def)
    $out = @()
    if (-not $Def.user -or -not $Def.user.paths) { return $out }
    $seen = @{}
    foreach ($tpl in $Def.user.paths) {
        $base = Expand-KersPath $tpl
        if (-not $base) { continue }
        try {
            if (-not (Test-Path -LiteralPath $base)) { continue }
            if ($Def.user.childPattern) {
                foreach ($d in (Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue)) {
                    if ($d.Name -notmatch $Def.user.childPattern) { continue }
                    $k = $d.FullName.ToLower()
                    if ($seen.ContainsKey($k)) { continue }
                    $seen[$k] = $true
                    $out += [pscustomobject]@{ Title = $d.Name; Path = $d.FullName }
                }
            } else {
                $k = $base.ToLower()
                if ($seen.ContainsKey($k)) { continue }
                $seen[$k] = $true
                $out += [pscustomobject]@{ Title = $Def.name; Path = $base }
            }
        } catch { }
    }
    return $out
}

function Get-KersGameInstances {
    # Liefert je Spiel(-Jahrgang) eine Instanz mit Installations- und
    # Benutzerordner. Eine Instanz kann auch nur eines von beidem haben.
    param($Def)
    $instances = @{}
    foreach ($i in (Find-KersInstalls $Def)) {
        $key = $i.Title.ToLower()
        $instances[$key] = [pscustomobject]@{
            GameId      = $Def.id
            GameName    = $Def.name
            Title       = $i.Title
            InstallPath = $i.Path
            UserPath    = $null
            Source      = $i.Source
            Definition  = $Def
        }
    }
    foreach ($u in (Find-KersUserDirs $Def)) {
        $key = $u.Title.ToLower()
        if ($instances.ContainsKey($key)) {
            $instances[$key].UserPath = $u.Path
        } else {
            $instances[$key] = [pscustomobject]@{
                GameId      = $Def.id
                GameName    = $Def.name
                Title       = $u.Title
                InstallPath = $null
                UserPath    = $u.Path
                Source      = 'Benutzerordner'
                Definition  = $Def
            }
        }
    }
    $list = @($instances.Values | Sort-Object Title)
    Write-KersLog ('Erkennung ' + $Def.id + ': ' + $list.Count + ' Instanz(en)') 'DEBUG'
    return $list
}

function Get-KersGameDefinitions {
    param([string]$JsonPath)
    if (-not (Test-Path -LiteralPath $JsonPath)) { throw ('games.json fehlt: ' + $JsonPath) }
    $json = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    return @($json.games)
}
