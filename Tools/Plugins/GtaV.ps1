# =====================================================================
#  KERS Plugin - Grand Theft Auto V
#
#  Einstellungen: Dokumente\Rockstar Games\GTA V\settings.xml
#  Mods: .asi-Dateien und der scripts\-Ordner im Spielordner.
#  Savegames unter profiles\ werden nicht angefasst.
#
#  WICHTIG: Mods gehoeren in den Storymodus. Mit aktiven Mods online zu
#  gehen fuehrt zu Sperren - deshalb gibt es hier das Umschalten, damit
#  vor GTA Online alles sauber deaktiviert werden kann.
# =====================================================================

function Get-KersGtaSettingsFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath -Names @('settings.xml', 'commandline.txt'))
}

function Get-KersGtaModDirs {
    param($Inst)
    if (-not $Inst.InstallPath) { return @{ Active = $null } }
    return @{
        Active   = $Inst.InstallPath
        Disabled = (Join-Path $Inst.InstallPath 'mods_disabled_kers')
        Filters  = @('*.asi')
    }
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersGtaSettingsFiles} `
                                       -Label 'Grafik-Profil' -Tag 'gfx' `
                                       -Examples '1440p_High, Performance' `
                                       -Hint 'settings.xml aus Dokumente\Rockstar Games\GTA V'
    $actions += New-KersModActions -GetDirs ${function:Get-KersGtaModDirs} -Label 'ASI-Mods' `
                                   -Hint 'schaltet .asi-Plugins im Spielordner um' `
                                   -Warning 'Vor GTA Online alle Mods deaktivieren - sonst droht eine Sperre.'

    return [pscustomobject]@{
        Id      = 'gta_v'
        Name    = 'Grand Theft Auto V'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if ($Inst.UserPath) {
                $s = Join-Path $Inst.UserPath 'settings.xml'
                if (Test-Path -LiteralPath $s) {
                    $lines += ('   settings.xml    : vorhanden (' + (Get-Item -LiteralPath $s).LastWriteTime.ToString('yyyy-MM-dd') + ')')
                    try {
                        $x = New-Object System.Xml.XmlDocument
                        $x.Load($s)
                        $n = $x.DocumentElement.SelectSingleNode('video')
                        if ($n) {
                            foreach ($a in @('ScreenWidth', 'ScreenHeight', 'Windowed')) {
                                $c = $n.SelectSingleNode($a)
                                if ($c) { $lines += ('   {0,-15} : {1}' -f $a, $c.get_Attributes()['value'].Value) }
                            }
                        }
                    } catch { }
                } else {
                    $lines += '   settings.xml    : nicht vorhanden'
                }
                $prof = Join-Path $Inst.UserPath 'Profiles'
                if (Test-Path -LiteralPath $prof) {
                    $n = @(Get-ChildItem -LiteralPath $prof -Directory -ErrorAction SilentlyContinue).Count
                    $lines += ('   Profiles        : ' + $n + ' (Savegames - werden nicht angefasst)')
                }
            }
            if ($Inst.InstallPath) {
                $d = Get-KersGtaModDirs $Inst
                $lines += ('   ASI-Mods        : ' + (Get-KersModCounts -Active $d.Active -Disabled $d.Disabled -Filters $d.Filters))
                foreach ($check in @(
                    @{ P = 'dinput8.dll'; N = 'ScriptHookV' },
                    @{ P = 'scripts';     N = 'scripts\' },
                    @{ P = 'mods';        N = 'mods\ (OpenIV)' })) {
                    $full = Join-Path $Inst.InstallPath $check.P
                    if (Test-Path -LiteralPath $full) {
                        $extra = ''
                        if ((Get-Item -LiteralPath $full).PSIsContainer) {
                            $extra = ' (' + @(Get-ChildItem -LiteralPath $full -ErrorAction SilentlyContinue).Count + ' Eintraege)'
                        }
                        $lines += ('   ' + $check.N + ': erkannt' + $extra)
                    }
                }
                $lines += '   Hinweis         : vor GTA Online alle Mods deaktivieren'
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
