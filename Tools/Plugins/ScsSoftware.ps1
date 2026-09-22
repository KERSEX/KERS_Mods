# =====================================================================
#  KERS Plugin - Euro Truck Simulator 2 und American Truck Simulator
#
#  Beide Spiele sind technisch gleich aufgebaut, deshalb bedient dieses
#  Plugin beide. Einstellungen liegen unter
#  Dokumente\<Spiel>\ : config.cfg (Grafik, FFB, alles) und
#  controls.sii (Tastenbelegung). Mods sind .scs-Dateien im Ordner mod\.
#  Savegames unter profiles\ werden nicht angefasst.
# =====================================================================

function Get-KersScsControlFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath -Names @('controls.sii'))
}

function Get-KersScsSettingsFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath -Names @('config.cfg', 'config_local.cfg'))
}

function Get-KersScsModDirs {
    param($Inst)
    return @{
        Active   = (Join-Path $Inst.UserPath 'mod')
        Disabled = (Join-Path $Inst.UserPath 'mod_disabled_kers')
        Filters  = @('*.scs', '*.zip')
    }
}

function Get-KersScsCfgValue {
    # config.cfg benutzt: uset r_fullscreen "1"
    param([string]$Path, [string]$Key)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        foreach ($l in (Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)) {
            if ($l -match ('^\s*uset\s+' + [regex]::Escape($Key) + '\s+"?([^"]*)"?\s*$')) { return $Matches[1] }
        }
    } catch { }
    return $null
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersScsControlFiles} `
                                       -Label 'Steuerungs-Profil' -Tag 'ctrl' `
                                       -Examples 'MOZA_R5, Gamepad' `
                                       -Hint 'controls.sii'
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersScsSettingsFiles} `
                                       -Label 'Grafik-/Spiel-Profil' -Tag 'gfx' `
                                       -Examples '1440p_High, Convoy' `
                                       -Hint 'config.cfg - enthaelt auch FFB und Lenkung'
    $actions += New-KersModActions -GetDirs ${function:Get-KersScsModDirs} -Label 'Mods' `
                                   -Hint 'verschiebt .scs-Dateien zwischen mod\ und mod_disabled_kers\'

    return [pscustomobject]@{
        Id      = 'scs'
        Name    = 'SCS Truck Simulator'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if (-not $Inst.UserPath) {
                $lines += '   Benutzerordner  : nicht gefunden'
                return $lines
            }
            $cfg = Join-Path $Inst.UserPath 'config.cfg'
            if (Test-Path -LiteralPath $cfg) {
                $lines += ('   config.cfg      : vorhanden (' + (Get-Item -LiteralPath $cfg).LastWriteTime.ToString('yyyy-MM-dd') + ')')
                foreach ($k in @('r_mode_width', 'r_mode_height', 'r_fullscreen', 'g_force_feedback',
                                 'g_steer_autocenter', 'r_frame_limit')) {
                    $v = Get-KersScsCfgValue -Path $cfg -Key $k
                    if ($null -ne $v -and $v -ne '') { $lines += ('   {0,-18} : {1}' -f $k, $v) }
                }
            } else {
                $lines += '   config.cfg      : nicht vorhanden'
            }
            $ctrl = Join-Path $Inst.UserPath 'controls.sii'
            $lines += ('   controls.sii    : ' + $(if (Test-Path -LiteralPath $ctrl) { 'vorhanden' } else { 'nicht vorhanden' }))
            $d = Get-KersScsModDirs $Inst
            $lines += ('   Mods            : ' + (Get-KersModCounts -Active $d.Active -Disabled $d.Disabled -Filters $d.Filters))
            $prof = Join-Path $Inst.UserPath 'profiles'
            if (Test-Path -LiteralPath $prof) {
                $n = @(Get-ChildItem -LiteralPath $prof -Directory -ErrorAction SilentlyContinue).Count
                $lines += ('   Profile         : ' + $n + ' (Savegames - werden nicht angefasst)')
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
