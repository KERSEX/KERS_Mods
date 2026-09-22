# =====================================================================
#  KERS Core - generische Spiel-Aktionen
#  Backup, Restore und Diagnose laufen fuer jedes Spiel gleich ab.
#  Was gesichert wird, steht in games.json ("backup"), nicht im Code.
# =====================================================================

# ---------------------------------------------------------------------
function Get-KersBackupSources {
    param($Inst)
    $src = @()
    $rel = $Inst.Definition.backup
    if (-not $rel) { return $src }
    foreach ($r in $rel) {
        if ($Inst.UserPath) {
            $p = Join-Path $Inst.UserPath $r
            if (Test-Path -LiteralPath $p) { $src += $p }
        }
    }
    return $src
}

function Invoke-KersBackupAction {
    param($Inst)
    Write-KersHead ('Backup - ' + $Inst.Title)
    $src = Get-KersBackupSources $Inst
    if ($src.Count -eq 0) {
        Write-KersWarn 'Keine sicherbaren Einstellungen gefunden.'
        if ($Inst.UserPath) { Write-KersDim ('Gesucht unter: ' + $Inst.UserPath) }
        return
    }
    foreach ($s in $src) { Write-KersDim ('sichert: ' + $s) }
    $label = Read-KersText '  Name des Backups' 'manuell'
    [void](New-KersBackup -GameId $Inst.GameId -Sources $src -Label $label -Note $Inst.Title)
}

function Invoke-KersRestoreAction {
    param($Inst)
    Write-KersHead ('Wiederherstellen - ' + $Inst.Title)
    $backups = @(Get-KersBackups -GameId $Inst.GameId)
    if ($backups.Count -eq 0) { Write-KersInfo 'Noch kein Backup vorhanden.'; return }
    Write-Host ''
    Show-KersBackupList $backups
    $keys = @(1..$backups.Count | ForEach-Object { [string]$_ }) + @('0')
    $sel = Read-KersKey '  Backup (0 = zurueck)' $keys
    if ($sel -eq '0') { return }
    $pick = $backups[[int]$sel - 1]
    Write-KersInfo 'Das Spiel sollte dabei geschlossen sein.'
    if (-not (Read-KersYesNo ('  "' + $pick.Name + '" wiederherstellen?') $true)) { return }
    [void](Restore-KersBackup -Backup $pick)
}

function Invoke-KersGameDiagnostics {
    param($Inst, $Plugin, $Ctx)
    Write-KersHead ('Diagnose - ' + $Inst.Title)
    Write-Host ('   Installation    : ' + $(if ($Inst.InstallPath) { $Inst.InstallPath } else { 'nicht gefunden' })) -ForegroundColor Gray
    Write-Host ('   Einstellungen   : ' + $(if ($Inst.UserPath)    { $Inst.UserPath }    else { 'nicht gefunden' })) -ForegroundColor Gray
    Write-Host ('   Backups         : ' + @(Get-KersBackups -GameId $Inst.GameId).Count) -ForegroundColor Gray
    if ($Plugin -and $Plugin.Diagnostics) {
        try {
            foreach ($l in (& $Plugin.Diagnostics $Ctx $Inst)) { Write-Host $l -ForegroundColor Gray }
        } catch {
            Write-KersError ('Plugin-Diagnose fehlgeschlagen: ' + $_.Exception.Message)
        }
    }
}

