# =====================================================================
#  KERS Plugin - Le Mans Ultimate
#
#  LMU stammt von rFactor 2 ab und legt seine Einstellungen im
#  Installationsordner unter UserData ab, nicht unter Dokumente.
#  Lenkrad und FFB stecken in Controller.JSON, der Rest in den
#  Spieler-Dateien.
# =====================================================================

function Get-KersLmuPlayerDir {
    param($Inst)
    if (-not $Inst.UserPath) { return $null }
    $p = Join-Path $Inst.UserPath 'player'
    if (Test-Path -LiteralPath $p) { return $p }
    return $Inst.UserPath
}

function Get-KersLmuControlFiles {
    param($Inst)
    $dir = Get-KersLmuPlayerDir $Inst
    if (-not $dir) { return @() }
    $out = @(Get-KersExistingPaths -Base $dir -Names @('Controller.JSON', 'controller.json'))
    # abweichende Schreibweisen und geraetespezifische Dateien mitnehmen
    foreach ($f in (Get-ChildItem -LiteralPath $dir -Filter '*ontroller*.json' -File -ErrorAction SilentlyContinue)) {
        if ($out -notcontains $f.FullName) { $out += $f.FullName }
    }
    return $out
}

function Get-KersLmuSettingsFiles {
    param($Inst)
    $dir = Get-KersLmuPlayerDir $Inst
    if (-not $dir) { return @() }
    $out = @()
    foreach ($f in (Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^(Settings|player|Config_DX11)\.(JSON|ini)$' })) {
        $out += $f.FullName
    }
    return $out
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersLmuControlFiles} `
                                       -Label 'Wheel-/FFB-Profil' -Tag 'ctrl' `
                                       -Examples 'MOZA_R5_Hyper, GTE' `
                                       -Hint 'Controller.JSON aus UserData\player'
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersLmuSettingsFiles} `
                                       -Label 'Grafik-/Spiel-Profil' -Tag 'gfx' `
                                       -Examples '1440p_Race, VR' `
                                       -Hint 'Settings.JSON / player.JSON / Config_DX11.ini - was da ist'

    return [pscustomobject]@{
        Id      = 'lmu'
        Name    = 'Le Mans Ultimate'
        Actions = $actions
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            $dir = Get-KersLmuPlayerDir $Inst
            if (-not $dir) {
                $lines += '   UserData        : nicht gefunden'
                return $lines
            }
            $lines += ('   UserData        : ' + $dir)
            $files = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)
            $lines += ('   Dateien         : ' + $files.Count)
            foreach ($f in ($files | Sort-Object Name | Select-Object -First 12)) {
                $lines += ('      {0,-28} {1,8} Byte   {2}' -f $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd'))
            }
            $ctrl = @(Get-KersLmuControlFiles $Inst)
            if ($ctrl.Count -gt 0) {
                $lines += ('   Controller      : ' + (Split-Path $ctrl[0] -Leaf))
                foreach ($k in @('Steering Wheel Range', 'FFB Overall Effects Strength', 'FFB Device Name')) {
                    $v = Get-KersJsonValue -Path $ctrl[0] -Dotted ('Force Feedback.' + $k)
                    if ($null -ne $v) { $lines += ('   {0,-15} : {1}' -f $k, $v) }
                }
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
