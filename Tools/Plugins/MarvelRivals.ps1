# =====================================================================
#  KERS Plugin - Marvel Rivals
#
#  Bewusst nur Einstellungen: gesichert und zurueckgespielt wird
#  ausschliesslich der Konfigurationsordner unter %LOCALAPPDATA%.
#  Am Spielordner wird nichts veraendert - keine Dateien, keine
#  Eingriffe, nichts was in die Naehe von Anti-Cheat kommt.
# =====================================================================

function Get-KersRivalsVideoFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath `
                                  -Names @('GameUserSettings.ini', 'Engine.ini', 'Scalability.ini'))
}

function Get-KersRivalsInputFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath -Names @('Input.ini', 'Game.ini'))
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersRivalsVideoFiles} `
                                       -Label 'Grafik-Profil' -Tag 'gfx' `
                                       -Examples 'Competitive, Quality' `
                                       -Hint 'GameUserSettings.ini und Engine.ini'
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersRivalsInputFiles} `
                                       -Label 'Steuerungs-Profil' -Tag 'ctrl' `
                                       -Examples 'Maus_800dpi, Controller' `
                                       -Hint 'Input.ini und Game.ini'

    return [pscustomobject]@{
        Id      = 'marvel_rivals'
        Name    = 'Marvel Rivals'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if (-not $Inst.UserPath) {
                $lines += '   Config-Ordner   : nicht gefunden'
                return $lines
            }
            $lines += ('   Config-Ordner   : ' + $Inst.UserPath)
            foreach ($f in (Get-ChildItem -LiteralPath $Inst.UserPath -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
                $lines += ('      {0,-28} {1,8} Byte   {2}' -f $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd'))
            }
            $gus = Join-Path $Inst.UserPath 'GameUserSettings.ini'
            foreach ($k in @('ResolutionSizeX', 'ResolutionSizeY', 'FullscreenMode', 'FrameRateLimit')) {
                $v = Get-KersIniValue -Path $gus -Key $k
                if ($v) { $lines += ('   {0,-15} : {1}' -f $k, $v) }
            }
            $lines += '   Spielordner     : wird von KERS nicht angefasst'
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
