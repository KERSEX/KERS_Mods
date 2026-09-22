# =====================================================================
#  KERS Plugin - Assetto Corsa Competizione
#
#  ACC legt alles unter Dokumente\Assetto Corsa Competizione\Config ab.
#  Welche Dateien es genau sind, unterscheidet sich je nach Version -
#  gesichert wird deshalb, was tatsaechlich da ist. Die Diagnose zeigt
#  den Ist-Zustand.
# =====================================================================

function Get-KersAccControlFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base (Join-Path $Inst.UserPath 'Config') `
                                  -Names @('controls.json', 'controlsBackup.json', 'ffbSettings.json'))
}

function Get-KersAccVideoFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base (Join-Path $Inst.UserPath 'Config') `
                                  -Names @('menuSettings.json', 'videoSettings.json', 'engine.ini', 'hud.json'))
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersAccControlFiles} `
                                       -Label 'Wheel-/FFB-Profil' -Tag 'ctrl' `
                                       -Examples 'MOZA_R5_GT3, LowForce' `
                                       -Hint 'controls.json und was an FFB-Dateien vorhanden ist'
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersAccVideoFiles} `
                                       -Label 'Grafik-Profil' -Tag 'gfx' `
                                       -Examples '1440p_High, 1440p_Performance' `
                                       -Hint 'menuSettings.json, engine.ini, hud.json - was da ist'

    return [pscustomobject]@{
        Id      = 'acc'
        Name    = 'Assetto Corsa Competizione'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if (-not $Inst.UserPath) {
                $lines += '   Config-Ordner   : nicht gefunden'
                return $lines
            }
            $cfg = Join-Path $Inst.UserPath 'Config'
            if (-not (Test-Path -LiteralPath $cfg)) {
                $lines += '   Config-Ordner   : nicht vorhanden (ACC einmal starten)'
                return $lines
            }
            $files = @(Get-ChildItem -LiteralPath $cfg -File -ErrorAction SilentlyContinue)
            $lines += ('   Config          : ' + $files.Count + ' Dateien')
            foreach ($f in ($files | Sort-Object Name)) {
                $lines += ('      {0,-28} {1,7} Byte   {2}' -f $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd'))
            }
            $ctrl = Join-Path $cfg 'controls.json'
            foreach ($k in @('steerLock', 'ffbGain', 'ffbMinForce', 'deviceName')) {
                $v = Get-KersJsonValue -Path $ctrl -Dotted $k
                if ($null -ne $v) { $lines += ('   {0,-15} : {1}' -f $k, $v) }
            }
            foreach ($sub in @('Setups', 'Customs', 'Replay')) {
                $p = Join-Path $Inst.UserPath $sub
                if (Test-Path -LiteralPath $p) {
                    $n = @(Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue).Count
                    $lines += ('   {0,-15} : {1} Dateien' -f $sub, $n)
                }
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
