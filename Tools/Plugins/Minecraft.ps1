# =====================================================================
#  KERS Plugin - Minecraft (Java Edition, offizieller Launcher)
#
#  %APPDATA%\.minecraft\ : options.txt, mods\, shaderpacks\,
#  resourcepacks\, saves\ (Welten - werden nicht angefasst).
#  Fremde Launcher wie Prism oder MultiMC verwalten eigene Instanzen und
#  werden hier nicht angefasst.
# =====================================================================

function Get-KersMcSettingsFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath `
                                  -Names @('options.txt', 'optionsof.txt', 'optionsshaders.txt', 'servers.dat'))
}

function Get-KersMcModDirs {
    param($Inst)
    return @{
        Active   = (Join-Path $Inst.UserPath 'mods')
        Disabled = (Join-Path $Inst.UserPath 'mods_disabled_kers')
        Filters  = @('*.jar')
    }
}

function Get-KersMcLoaders {
    param($Inst)
    $found = @()
    $v = Join-Path $Inst.UserPath 'versions'
    if (Test-Path -LiteralPath $v) {
        foreach ($d in (Get-ChildItem -LiteralPath $v -Directory -ErrorAction SilentlyContinue)) {
            foreach ($l in @('fabric', 'forge', 'neoforge', 'quilt', 'optifine')) {
                if ($d.Name -match ('(?i)' + $l) -and ($found -notcontains $l)) { $found += $l }
            }
        }
    }
    return $found
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersMcSettingsFiles} `
                                       -Label 'Einstellungs-Profil' -Tag 'cfg' `
                                       -Examples 'Vanilla, Shader_Setup' `
                                       -Hint 'options.txt und die Zusatzdateien von OptiFine/Shadern'
    $actions += New-KersModActions -GetDirs ${function:Get-KersMcModDirs} -Label 'Mods (.jar)' `
                                   -Hint 'mods\ - verschiebt, loescht nie'

    return [pscustomobject]@{
        Id      = 'minecraft'
        Name    = 'Minecraft (Java)'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if (-not $Inst.UserPath) {
                $lines += '   .minecraft      : nicht gefunden'
                return $lines
            }
            $lines += ('   .minecraft      : ' + $Inst.UserPath)
            $loaders = @(Get-KersMcLoaders $Inst)
            $lines += ('   Mod-Loader      : ' + $(if ($loaders.Count) { $loaders -join ', ' } else { 'keiner erkannt (Vanilla)' }))
            $d = Get-KersMcModDirs $Inst
            $lines += ('   Mods            : ' + (Get-KersModCounts -Active $d.Active -Disabled $d.Disabled -Filters $d.Filters))
            foreach ($what in @('shaderpacks', 'resourcepacks', 'saves', 'versions')) {
                $p = Join-Path $Inst.UserPath $what
                if (Test-Path -LiteralPath $p) {
                    $n = @(Get-ChildItem -LiteralPath $p -ErrorAction SilentlyContinue).Count
                    $note = if ($what -eq 'saves') { ' (Welten - werden nicht angefasst)' } else { '' }
                    $lines += ('   {0,-15} : {1} Eintraege{2}' -f $what, $n, $note)
                }
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
