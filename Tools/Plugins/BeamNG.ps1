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
    return @{
        Active   = (Join-Path $Inst.UserPath 'mods')
        Disabled = (Join-Path $Inst.UserPath 'mods_disabled_kers')
        Filters  = @('*.zip')
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
    $actions += New-KersModActions -GetDirs ${function:Get-KersBngModDirs} -Label 'Mods' `
                                   -Hint 'verschiebt ZIPs zwischen mods\ und mods_disabled_kers\'

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
            $d = Get-KersBngModDirs $Inst
            $lines += ('   Mods            : ' + (Get-KersModCounts -Active $d.Active -Disabled $d.Disabled -Filters $d.Filters))
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
