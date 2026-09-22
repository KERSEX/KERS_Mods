# =====================================================================
#  KERS Core - gemeinsame Simracing-Bausteine
#
#  Assetto Corsa, ACC und Le Mans Ultimate machen dasselbe: eine Handvoll
#  Konfigurationsdateien als benanntes Profil ablegen und wieder
#  zurueckholen. Der Ablauf steht deshalb einmal hier; ein Plugin sagt nur
#  noch, welche Dateien zu einem Profil gehoeren.
# =====================================================================

function Get-KersExistingPaths {
    # Liefert aus einer Liste relativer Namen die tatsaechlich vorhandenen
    # vollen Pfade unterhalb von $Base.
    param([string]$Base, [string[]]$Names)
    $out = @()
    if (-not $Base) { return $out }
    foreach ($n in $Names) {
        $p = Join-Path $Base $n
        if (Test-Path -LiteralPath $p) { $out += $p }
    }
    return $out
}

function New-KersProfileActions {
    <#
      Baut die drei Menuepunkte Speichern / Laden / Verwalten fuer eine
      Gruppe von Konfigurationsdateien.

      -GetFiles  Scriptblock, bekommt die Spiel-Instanz und liefert die
                 zu sichernden Pfade zurueck.
      -Label     Wie das Profil im Menue heisst, z.B. 'Controller-Profil'.
      -Examples  Beispielnamen fuer die Eingabe, z.B. 'GT3, Drift'.
      -Kind      Ablage-Art im Backup-Manager (Vorgabe 'profile').
    #>
    param(
        [Parameter(Mandatory = $true)][scriptblock]$GetFiles,
        [string]$Label = 'Profil',
        [string]$Hint = '',
        [string]$Examples = '',
        [ValidateSet('profile', 'backup')][string]$Kind = 'profile',
        [string]$Tag = ''
    )

    $saveText = $Label + ' speichern'
    $loadText = $Label + ' laden'
    $mgmtText = $Label + 'e verwalten (pruefen, loeschen)'
    if ($Label.EndsWith('e')) { $mgmtText = $Label + 'n verwalten (pruefen, loeschen)' }

    $save = {
        param($Ctx, $Inst)
        $files = @(& $GetFiles $Inst)
        if ($files.Count -eq 0) {
            Write-KersWarn ('Keine Konfigurationsdateien gefunden - ' + $Inst.Title + ' einmal starten und einrichten.')
            return
        }
        foreach ($f in $files) { Write-KersDim ('sichert: ' + $f) }
        $prompt = '  Name des Profils'
        if ($Examples) { $prompt = $prompt + ' (z.B. ' + $Examples + ')' }
        $name = Read-KersText $prompt
        if (-not $name) { Write-KersInfo 'Abgebrochen.'; return }
        $note = Read-KersText '  Notiz (optional)'
        if ($Tag) { $name = $Tag + '_' + $name }
        [void](New-KersBackup -GameId $Inst.GameId -Sources $files -Label $name -Note $note -Kind $Kind)
    }.GetNewClosure()

    $load = {
        param($Ctx, $Inst)
        $list = @(Get-KersBackups -GameId $Inst.GameId -Kind $Kind)
        if ($Tag) { $list = @($list | Where-Object { $_.Label -like ($Tag + '_*') }) }
        if ($list.Count -eq 0) { Write-KersInfo 'Noch nichts gespeichert.'; return }
        Write-Host ''
        Show-KersBackupList $list
        $keys = @(1..$list.Count | ForEach-Object { [string]$_ }) + @('0')
        $sel = Read-KersKey '  Auswahl (0 = zurueck)' $keys
        if ($sel -eq '0') { return }
        $pick = $list[[int]$sel - 1]
        Write-KersInfo ($Inst.Title + ' sollte dabei geschlossen sein.')
        if (-not (Read-KersYesNo ('  "' + $pick.Label + '" laden?') $true)) { return }
        [void](Restore-KersBackup -Backup $pick)
    }.GetNewClosure()

    $manage = {
        param($Ctx, $Inst)
        $list = @(Get-KersBackups -GameId $Inst.GameId -Kind $Kind)
        if ($Tag) { $list = @($list | Where-Object { $_.Label -like ($Tag + '_*') }) }
        if ($list.Count -eq 0) { Write-KersInfo 'Noch nichts gespeichert.'; return }
        Write-Host ''
        Show-KersBackupList $list
        $keys = @(1..$list.Count | ForEach-Object { [string]$_ }) + @('0')
        $sel = Read-KersKey '  Auswahl (0 = zurueck)' $keys
        if ($sel -eq '0') { return }
        $pick = $list[[int]$sel - 1]
        $chk = Test-KersBackup -Backup $pick
        if ($chk.Valid) { Write-KersOk ('Integritaet in Ordnung (' + $chk.Ok + ' Dateien)') }
        else            { Write-KersWarn ($chk.Changed.ToString() + ' veraendert, ' + $chk.Missing + ' fehlen') }
        foreach ($e in $pick.Entries) { Write-KersDim ('   ' + $e.Relative) }
        if (Read-KersYesNo '  Diesen Eintrag loeschen?' $false) {
            if (Remove-KersBackup -Backup $pick) { Write-KersOk 'Geloescht.' }
        }
    }.GetNewClosure()

    return @(
        [pscustomobject]@{ Text = $saveText; Hint = $Hint; Run = $save },
        [pscustomobject]@{ Text = $loadText; Hint = 'der aktuelle Stand wird vorher automatisch gesichert'; Run = $load },
        [pscustomobject]@{ Text = $mgmtText; Hint = ''; Run = $manage }
    )
}

function Get-KersIniValue {
    # Liest einen Wert aus einer INI-aehnlichen Datei (erste Fundstelle).
    param([string]$Path, [string]$Key)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        foreach ($l in (Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)) {
            if ($l -match ('^\s*' + [regex]::Escape($Key) + '\s*=\s*(.+?)\s*$')) { return $Matches[1] }
        }
    } catch { }
    return $null
}

function Get-KersJsonValue {
    # Liest einen verschachtelten Wert aus einer JSON-Datei, Pfad mit
    # Punkten: 'controls.steerLock'. Fehlt etwas, kommt $null zurueck.
    param([string]$Path, [string]$Dotted)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $o = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($part in ($Dotted -split '\.')) {
            if ($null -eq $o) { return $null }
            $o = $o.$part
        }
        return $o
    } catch { return $null }
}
