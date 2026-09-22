# =====================================================================
#  KERS Plugin - Assetto Corsa
#
#  Profile sind benannte Backups der Eingabe-Konfiguration:
#    Dokumente\Assetto Corsa\cfg\controls.ini
#    Dokumente\Assetto Corsa\cfg\controllers\
#  Damit lassen sich MOZA-Einstellungen (FFB, Gain, Rotation, Effekte)
#  pro Fahrzeugklasse ablegen und zurueckholen.
#  Es werden keine fremden Mods mitgeliefert oder heruntergeladen.
# =====================================================================

function Get-KersAcControlPaths {
    param($Inst)
    if (-not $Inst.UserPath) { return @() }
    $cfg = Join-Path $Inst.UserPath 'cfg'
    $p = @()
    foreach ($n in @('controls.ini', 'controllers', 'ff_post_process.ini')) {
        $full = Join-Path $cfg $n
        if (Test-Path -LiteralPath $full) { $p += $full }
    }
    return $p
}

function Get-KersPlugin {
    return [pscustomobject]@{
        Id      = 'assetto_corsa'
        Name    = 'Assetto Corsa'
        Actions = @(
            [pscustomobject]@{
                Text = 'Controller-Profil speichern (FFB, Gain, Rotation, Effekte)'
                Hint = 'sichert controls.ini, controllers\ und ff_post_process.ini'
                Run  = {
                    param($Ctx, $Inst)
                    $paths = Get-KersAcControlPaths $Inst
                    if ($paths.Count -eq 0) {
                        Write-KersWarn 'Keine Eingabe-Konfiguration gefunden. Assetto Corsa einmal starten und ein Lenkrad einrichten.'
                        return
                    }
                    $name = Read-KersText '  Name des Profils (z.B. GT3, Drift, Formula)'
                    if (-not $name) { Write-KersInfo 'Abgebrochen.'; return }
                    $note = Read-KersText '  Notiz (optional)'
                    [void](New-KersBackup -GameId $Inst.GameId -Sources $paths -Label $name -Note $note -Kind 'profile')
                }
            },
            [pscustomobject]@{
                Text = 'Controller-Profil laden'
                Hint = 'der aktuelle Stand wird vorher automatisch gesichert'
                Run  = {
                    param($Ctx, $Inst)
                    $profiles = @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile')
                    if ($profiles.Count -eq 0) { Write-KersInfo 'Noch kein Profil gespeichert.'; return }
                    Write-Host ''
                    Show-KersBackupList $profiles
                    $keys = @(1..$profiles.Count | ForEach-Object { [string]$_ }) + @('0')
                    $sel = Read-KersKey '  Profil (0 = zurueck)' $keys
                    if ($sel -eq '0') { return }
                    $pick = $profiles[[int]$sel - 1]
                    Write-KersInfo ('Assetto Corsa sollte dabei geschlossen sein.')
                    if (-not (Read-KersYesNo ('  Profil "' + $pick.Label + '" laden?') $true)) { return }
                    [void](Restore-KersBackup -Backup $pick)
                }
            },
            [pscustomobject]@{
                Text = 'Profile verwalten (pruefen, loeschen)'
                Run  = {
                    param($Ctx, $Inst)
                    $profiles = @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile')
                    if ($profiles.Count -eq 0) { Write-KersInfo 'Noch kein Profil gespeichert.'; return }
                    Write-Host ''
                    Show-KersBackupList $profiles
                    $keys = @(1..$profiles.Count | ForEach-Object { [string]$_ }) + @('0')
                    $sel = Read-KersKey '  Profil (0 = zurueck)' $keys
                    if ($sel -eq '0') { return }
                    $pick = $profiles[[int]$sel - 1]
                    $chk = Test-KersBackup -Backup $pick
                    if ($chk.Valid) { Write-KersOk ('Integritaet in Ordnung (' + $chk.Ok + ' Dateien)') }
                    else            { Write-KersWarn ($chk.Changed.ToString() + ' veraendert, ' + $chk.Missing + ' fehlen') }
                    if (Read-KersYesNo '  Dieses Profil loeschen?' $false) {
                        [void](Remove-KersBackup -Backup $pick)
                        Write-KersOk 'Geloescht.'
                    }
                }
            }
        )
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if ($Inst.UserPath) {
                $cfg = Join-Path $Inst.UserPath 'cfg'
                $ctrl = Join-Path $cfg 'controls.ini'
                if (Test-Path -LiteralPath $ctrl) {
                    $lines += ('   controls.ini    : vorhanden (' + (Get-Item -LiteralPath $ctrl).LastWriteTime.ToString('yyyy-MM-dd') + ')')
                    try {
                        foreach ($l in (Get-Content -LiteralPath $ctrl -ErrorAction SilentlyContinue | Select-Object -First 40)) {
                            if ($l -match '^\s*INPUT\s*=\s*(.+?)\s*$')      { $lines += ('   Eingabegeraet   : ' + $Matches[1]) }
                            if ($l -match '^\s*STEER_LOCK\s*=\s*(.+?)\s*$') { $lines += ('   Lenkwinkel      : ' + $Matches[1]) }
                        }
                    } catch { }
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
