# =====================================================================
#  KERS Plugin - Cyberpunk 2077
#
#  Einstellungen: Dokumente\CD Projekt Red\Cyberpunk 2077\
#  Mods: <Spielordner>\archive\pc\mod\*.archive
#  Spieldateien werden nicht veraendert - Mods werden nur verschoben.
#  Presets sind Sicherungen deiner eigenen Einstellungen, keine
#  behaupteten Optimal-Werte.
# =====================================================================

function Get-KersCpSettingsFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath `
                                  -Names @('UserSettings.json', 'inputUserMappings.xml', 'GraphicsSettings.json'))
}

function Get-KersCpModDirs {
    param($Inst)
    if (-not $Inst.InstallPath) { return @{ Active = $null } }
    return @{
        Active   = (Join-Path $Inst.InstallPath 'archive\pc\mod')
        Disabled = (Join-Path $Inst.InstallPath 'archive\pc\mod_disabled_kers')
        Filters  = @('*.archive', '*.xl')
    }
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersCpSettingsFiles} `
                                       -Label 'Einstellungs-Profil' -Tag 'gfx' `
                                       -Examples '1440p_Quality, Performance' `
                                       -Hint 'UserSettings.json - Grafik, Steuerung und Spieloptionen'
    $actions += New-KersModActions -GetDirs ${function:Get-KersCpModDirs} -Label 'Mods (.archive)' `
                                   -Hint 'archive\pc\mod - verschiebt, loescht nie'

    return [pscustomobject]@{
        Id      = 'cyberpunk2077'
        Name    = 'Cyberpunk 2077'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if ($Inst.UserPath) {
                $us = Join-Path $Inst.UserPath 'UserSettings.json'
                if (Test-Path -LiteralPath $us) {
                    $lines += ('   UserSettings    : vorhanden (' + (Get-Item -LiteralPath $us).LastWriteTime.ToString('yyyy-MM-dd') +
                               ', ' + [math]::Round((Get-Item -LiteralPath $us).Length / 1KB) + ' KB)')
                } else {
                    $lines += '   UserSettings    : nicht vorhanden'
                }
            }
            if ($Inst.InstallPath) {
                $d = Get-KersCpModDirs $Inst
                $lines += ('   Mods (.archive) : ' + (Get-KersModCounts -Active $d.Active -Disabled $d.Disabled -Filters $d.Filters))
                foreach ($check in @(
                    @{ P = 'bin\x64\plugins\cyber_engine_tweaks'; N = 'Cyber Engine Tweaks' },
                    @{ P = 'bin\x64\version.dll';                 N = 'RED4ext/CET-Loader' },
                    @{ P = 'r6\scripts';                          N = 'redscript (r6\scripts)' },
                    @{ P = 'mods';                                N = 'REDmod (mods\)' })) {
                    $full = Join-Path $Inst.InstallPath $check.P
                    if (Test-Path -LiteralPath $full) {
                        $extra = ''
                        if ((Get-Item -LiteralPath $full).PSIsContainer) {
                            $extra = ' (' + @(Get-ChildItem -LiteralPath $full -ErrorAction SilentlyContinue).Count + ' Eintraege)'
                        }
                        $lines += ('   ' + $check.N + ': erkannt' + $extra)
                    }
                }
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
