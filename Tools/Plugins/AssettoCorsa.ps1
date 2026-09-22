# =====================================================================
#  KERS Plugin - Assetto Corsa
#
#  Profile sind benannte Sicherungen der Eingabe-Konfiguration aus
#  Dokumente\Assetto Corsa\cfg. Damit lassen sich MOZA-Einstellungen
#  (FFB, Gain, Rotation, Effekte) je Fahrzeugklasse ablegen.
#  Es werden keine fremden Mods mitgeliefert oder heruntergeladen.
# =====================================================================

function Get-KersAcControlFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base (Join-Path $Inst.UserPath 'cfg') `
                                  -Names @('controls.ini', 'controllers', 'ff_post_process.ini'))
}

function Get-KersAcVideoFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base (Join-Path $Inst.UserPath 'cfg') `
                                  -Names @('video.ini', 'assetto_corsa.ini', 'graphics.ini'))
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersAcControlFiles} `
                                       -Label 'Controller-Profil' -Tag 'ctrl' `
                                       -Examples 'GT3, Drift, Formula' `
                                       -Hint 'controls.ini, controllers\ und ff_post_process.ini'
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersAcVideoFiles} `
                                       -Label 'Grafik-Profil' -Tag 'gfx' `
                                       -Examples '1440p_Quality, VR' `
                                       -Hint 'video.ini und assetto_corsa.ini'

    return [pscustomobject]@{
        Id      = 'assetto_corsa'
        Name    = 'Assetto Corsa'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if ($Inst.UserPath) {
                $cfg  = Join-Path $Inst.UserPath 'cfg'
                $ctrl = Join-Path $cfg 'controls.ini'
                if (Test-Path -LiteralPath $ctrl) {
                    $lines += ('   controls.ini    : vorhanden (' + (Get-Item -LiteralPath $ctrl).LastWriteTime.ToString('yyyy-MM-dd') + ')')
                    $v = Get-KersIniValue -Path $ctrl -Key 'INPUT'
                    if ($v) { $lines += ('   Eingabegeraet   : ' + $v) }
                    $v = Get-KersIniValue -Path $ctrl -Key 'STEER_LOCK'
                    if ($v) { $lines += ('   Lenkwinkel      : ' + $v) }
                    $v = Get-KersIniValue -Path $ctrl -Key 'FF_GAIN'
                    if ($v) { $lines += ('   FFB Gain        : ' + $v) }
                } else {
                    $lines += '   controls.ini    : nicht vorhanden'
                }
                $n = @(Get-ChildItem -LiteralPath (Join-Path $cfg 'controllers') -Recurse -File -ErrorAction SilentlyContinue).Count
                $lines += ('   controllers\    : ' + $n + ' Dateien')
            }
            if ($Inst.InstallPath) {
                $csp = (Test-Path -LiteralPath (Join-Path $Inst.InstallPath 'dwrite.dll')) -or
                       (Test-Path -LiteralPath (Join-Path $Inst.InstallPath 'extension'))
                $lines += ('   Custom Shaders  : ' + $(if ($csp) { 'erkannt' } else { 'nicht erkannt' }))
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
