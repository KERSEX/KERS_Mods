# =====================================================================
#  KERS Plugin - BeamNG.drive
#
#  BeamNG legt seine Einstellungen unter
#  %LOCALAPPDATA%\BeamNG.drive\<version>\ ab. Mods sind ZIP-Dateien in
#  mods\. Zum Deaktivieren werden sie verschoben, nie geloescht:
#    <version>\mods\              aktiv
#    <version>\mods_disabled_kers\  deaktiviert
# =====================================================================

function Get-KersBngControlFiles {
    param($Inst)
    $s = Join-Path $Inst.UserPath 'settings'
    return (Get-KersExistingPaths -Base $s -Names @('inputmaps', 'controls.json'))
}

function Get-KersBngSettingsFiles {
    param($Inst)
    $s = Join-Path $Inst.UserPath 'settings'
    return (Get-KersExistingPaths -Base $s -Names @('game-settings.ini', 'graphics.json', 'cloud'))
}

function Get-KersBngModDirs {
    param($Inst)
    return [pscustomobject]@{
        Active   = (Join-Path $Inst.UserPath 'mods')
        Disabled = (Join-Path $Inst.UserPath 'mods_disabled_kers')
    }
}

function Get-KersBngMods {
    param($Inst)
    $d = Get-KersBngModDirs $Inst
    $out = @()
    foreach ($f in (Get-ChildItem -LiteralPath $d.Active -Filter '*.zip' -File -ErrorAction SilentlyContinue)) {
        $out += [pscustomobject]@{ Name = $f.Name; Path = $f.FullName; Enabled = $true; Size = $f.Length }
    }
    foreach ($f in (Get-ChildItem -LiteralPath $d.Disabled -Filter '*.zip' -File -ErrorAction SilentlyContinue)) {
        $out += [pscustomobject]@{ Name = $f.Name; Path = $f.FullName; Enabled = $false; Size = $f.Length }
    }
    return @($out | Sort-Object Name)
}

function Invoke-KersBngMods {
    param($Ctx, $Inst)
    $dirs = Get-KersBngModDirs $Inst
    while ($true) {
        $mods = @(Get-KersBngMods $Inst)
        Write-Host ''
        if ($mods.Count -eq 0) {
            Write-KersInfo 'Keine Mods gefunden.'
            Write-KersDim ('Gesucht in: ' + $dirs.Active)
            return
        }
        Write-Host ('  Mods (' + @($mods | Where-Object { $_.Enabled }).Count + ' aktiv, ' +
                    @($mods | Where-Object { -not $_.Enabled }).Count + ' deaktiviert)') -ForegroundColor White
        for ($i = 0; $i -lt $mods.Count; $i++) {
            $m = $mods[$i]
            $state = if ($m.Enabled) { '[an] ' } else { '[aus]' }
            $col   = if ($m.Enabled) { 'Green' } else { 'DarkGray' }
            Write-Host ('   {0,2}) {1} {2,-42} {3,8:N0} KB' -f ($i + 1), $state, $m.Name, ($m.Size / 1KB)) -ForegroundColor $col
        }
        Write-KersDim 'Nummer schaltet um. Deaktivierte Mods werden verschoben, nicht geloescht.'
        $keys = @(1..$mods.Count | ForEach-Object { [string]$_ }) + @('0')
        $sel = Read-KersKey '  Auswahl (0 = zurueck)' $keys '0'
        if ($sel -eq '0') { return }

        $m = $mods[[int]$sel - 1]
        $target = if ($m.Enabled) { $dirs.Disabled } else { $dirs.Active }
        try {
            if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
            Move-Item -LiteralPath $m.Path -Destination (Join-Path $target $m.Name) -Force
            $what = if ($m.Enabled) { 'deaktiviert' } else { 'aktiviert' }
            Write-KersOk ($m.Name + ' ' + $what)
            Write-KersLog ('Mod ' + $what + ': ' + $m.Name) 'INFO'
        } catch {
            Write-KersError ($m.Name + ': ' + $_.Exception.Message)
        }
    }
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersBngControlFiles} `
                                       -Label 'Controller-Profil' -Tag 'ctrl' `
                                       -Examples 'MOZA_R5, Gamepad' `
                                       -Hint 'settings\inputmaps'
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersBngSettingsFiles} `
                                       -Label 'Grafik-/Spiel-Profil' -Tag 'gfx' `
                                       -Examples '1440p_High, Performance' `
                                       -Hint 'settings\game-settings.ini und was daneben liegt'
    $actions += [pscustomobject]@{
        Text = 'Mods aktivieren / deaktivieren'
        Hint = 'verschiebt ZIPs zwischen mods\ und mods_disabled_kers\ - nichts wird geloescht'
        Run  = { param($Ctx, $Inst) Invoke-KersBngMods $Ctx $Inst }
    }

    return [pscustomobject]@{
        Id      = 'beamng'
        Name    = 'BeamNG.drive'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if (-not $Inst.UserPath) {
                $lines += '   Benutzerordner  : nicht gefunden'
                return $lines
            }
            $lines += ('   Version         : ' + (Split-Path $Inst.UserPath -Leaf))
            $s = Join-Path $Inst.UserPath 'settings'
            if (Test-Path -LiteralPath $s) {
                $n = @(Get-ChildItem -LiteralPath $s -Recurse -File -ErrorAction SilentlyContinue).Count
                $lines += ('   settings\       : ' + $n + ' Dateien')
                $im = Join-Path $s 'inputmaps'
                if (Test-Path -LiteralPath $im) {
                    foreach ($f in (Get-ChildItem -LiteralPath $im -File -ErrorAction SilentlyContinue | Select-Object -First 8)) {
                        $lines += ('      ' + $f.Name)
                    }
                }
            } else {
                $lines += '   settings\       : nicht vorhanden'
            }
            $mods = @(Get-KersBngMods $Inst)
            $lines += ('   Mods            : ' + @($mods | Where-Object { $_.Enabled }).Count + ' aktiv, ' +
                       @($mods | Where-Object { -not $_.Enabled }).Count + ' deaktiviert')
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
