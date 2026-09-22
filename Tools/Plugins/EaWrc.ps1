# =====================================================================
#  KERS Plugin - EA Sports WRC
#
#  Unreal-Engine-Titel: die Konfiguration liegt unter
#  %LOCALAPPDATA%\WRC\Saved\Config\... - je nach Version in Windows
#  oder WindowsNoEditor. Gesichert wird, was tatsaechlich da ist.
# =====================================================================

function Get-KersWrcControlFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath -Names @('Input.ini', 'DeviceProfiles.ini'))
}

function Get-KersWrcVideoFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base $Inst.UserPath `
                                  -Names @('GameUserSettings.ini', 'Engine.ini', 'Scalability.ini', 'Game.ini'))
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersWrcControlFiles} `
                                       -Label 'Wheel-/FFB-Profil' -Tag 'ctrl' `
                                       -Examples 'MOZA_R5_Rally' `
                                       -Hint 'Input.ini aus dem Saved\Config-Ordner'
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersWrcVideoFiles} `
                                       -Label 'Grafik-Profil' -Tag 'gfx' `
                                       -Examples '1440p_High, Performance' `
                                       -Hint 'GameUserSettings.ini, Engine.ini, Scalability.ini'

    return [pscustomobject]@{
        Id      = 'ea_wrc'
        Name    = 'EA Sports WRC'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if (-not $Inst.UserPath) {
                $lines += '   Config-Ordner   : nicht gefunden'
                return $lines
            }
            $lines += ('   Config-Ordner   : ' + $Inst.UserPath)
            $files = @(Get-ChildItem -LiteralPath $Inst.UserPath -File -ErrorAction SilentlyContinue)
            $lines += ('   Dateien         : ' + $files.Count)
            foreach ($f in ($files | Sort-Object Name)) {
                $lines += ('      {0,-28} {1,8} Byte   {2}' -f $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd'))
            }
            $gus = Join-Path $Inst.UserPath 'GameUserSettings.ini'
            foreach ($k in @('ResolutionSizeX', 'ResolutionSizeY', 'FullscreenMode', 'FrameRateLimit')) {
                $v = Get-KersIniValue -Path $gus -Key $k
                if ($v) { $lines += ('   {0,-15} : {1}' -f $k, $v) }
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
