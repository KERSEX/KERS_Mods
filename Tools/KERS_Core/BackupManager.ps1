# =====================================================================
#  KERS Core - Backups
#  Ablage:  %LOCALAPPDATA%\KERS_Mods\backups\<spiel>\<zeitstempel>_<label>
#           ├── backup.json   (Manifest mit Quelle, Groesse, SHA256)
#           └── files\...     (Kopien)
#  Jede potentiell destruktive Aktion legt vorher ein Backup an.
# =====================================================================

function Get-KersBackupRoot {
    return (Join-Path (Get-KersDataDir) 'backups')
}

function Get-KersFileHash256 {
    param([string]$Path)
    try { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
    catch { return '' }
}

function New-KersBackup {
    <#
      Sichert eine Liste von Dateien/Ordnern.
      -Sources: absolute Pfade. Nicht vorhandene werden uebersprungen.
      Rueckgabe: Backup-Objekt oder $null, wenn nichts zu sichern war.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$GameId,
        [Parameter(Mandatory = $true)][string[]]$Sources,
        [string]$Label = 'backup',
        [string]$Note = '',
        [ValidateSet('backup', 'profile', 'safety')]
        [string]$Kind = 'backup',
        [switch]$Quiet
    )
    $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $name  = $stamp + '_' + (ConvertTo-KersSafeName $Label)
    $dir   = Join-Path (Join-Path (Get-KersBackupRoot) (ConvertTo-KersSafeName $GameId)) $name
    $files = Join-Path $dir 'files'
    $entries = @()

    try {
        New-Item -ItemType Directory -Path $files -Force | Out-Null
        foreach ($src in $Sources) {
            if (-not $src) { continue }
            if (-not (Test-Path -LiteralPath $src)) { continue }
            $leaf = Split-Path $src -Leaf
            $dest = Join-Path $files $leaf
            $item = Get-Item -LiteralPath $src
            if ($item.PSIsContainer) {
                Copy-Item -LiteralPath $src -Destination $files -Recurse -Force
                foreach ($f in (Get-ChildItem -LiteralPath $dest -Recurse -File -ErrorAction SilentlyContinue)) {
                    $entries += [pscustomobject]@{
                        Source   = $src
                        Relative = $f.FullName.Substring($files.Length).TrimStart('\', '/')
                        Size     = $f.Length
                        Sha256   = (Get-KersFileHash256 $f.FullName)
                    }
                }
            } else {
                Copy-Item -LiteralPath $src -Destination $dest -Force
                $entries += [pscustomobject]@{
                    Source   = $src
                    Relative = $leaf
                    Size     = (Get-Item -LiteralPath $dest).Length
                    Sha256   = (Get-KersFileHash256 $dest)
                }
            }
        }
    } catch {
        Write-KersError ('Backup fehlgeschlagen: ' + $_.Exception.Message)
        try { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        return $null
    }

    if ($entries.Count -eq 0) {
        try { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        if (-not $Quiet) { Write-KersWarn 'Nichts zu sichern gefunden.' }
        return $null
    }

    $manifest = [pscustomobject]@{
        game    = $GameId
        kind    = $Kind
        label   = $Label
        note    = $Note
        created = (Get-Date -Format 's')
        host    = $env:COMPUTERNAME
        entries = $entries
    }
    try {
        $json = ConvertTo-Json -InputObject $manifest -Depth 6
        Set-Content -LiteralPath (Join-Path $dir 'backup.json') -Value $json -Encoding UTF8
    } catch {
        Write-KersError ('Manifest konnte nicht geschrieben werden: ' + $_.Exception.Message)
        return $null
    }

    Write-KersLog ('Backup ' + $GameId + ' -> ' + $dir + ' (' + $entries.Count + ' Dateien)') 'INFO'
    if (-not $Quiet) {
        Write-KersOk ($entries.Count.ToString() + ' Dateien gesichert')
        Write-KersDim $dir
    }
    return (Get-KersBackup -Path $dir)
}

function Get-KersBackup {
    param([string]$Path)
    $mf = Join-Path $Path 'backup.json'
    if (-not (Test-Path -LiteralPath $mf)) { return $null }
    try {
        $m = Get-Content -LiteralPath $mf -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { return $null }
    $kind = if ($m.kind) { [string]$m.kind } else { 'backup' }
    return [pscustomobject]@{
        Path     = $Path
        Name     = (Split-Path $Path -Leaf)
        GameId   = $m.game
        Kind     = $kind
        Label    = $m.label
        Note     = $m.note
        Created  = $m.created
        Entries  = @($m.entries)
        Files    = (Join-Path $Path 'files')
    }
}

function Get-KersBackups {
    # -Kind filtert: 'backup' (manuell), 'profile' (benannte Profile),
    # 'safety' (automatisch vor einer Wiederherstellung). Ohne -Kind alles.
    param([string]$GameId, [ValidateSet('', 'backup', 'profile', 'safety')][string]$Kind = '')
    $dir = Join-Path (Get-KersBackupRoot) (ConvertTo-KersSafeName $GameId)
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    $out = @()
    foreach ($d in (Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
        $b = Get-KersBackup -Path $d.FullName
        if (-not $b) { continue }
        if ($Kind -and ($b.Kind -ne $Kind)) { continue }
        $out += $b
    }
    return $out
}

function Test-KersBackup {
    # Integritaetspruefung gegen die SHA256-Summen im Manifest
    param($Backup)
    $ok = 0; $bad = 0; $missing = 0
    foreach ($e in $Backup.Entries) {
        $f = Join-Path $Backup.Files $e.Relative
        if (-not (Test-Path -LiteralPath $f)) { $missing++; continue }
        if (-not $e.Sha256) { $ok++; continue }
        if ((Get-KersFileHash256 $f) -eq $e.Sha256) { $ok++ } else { $bad++ }
    }
    return [pscustomobject]@{ Ok = $ok; Changed = $bad; Missing = $missing; Valid = (($bad + $missing) -eq 0) }
}

function Restore-KersBackup {
    <#
      Spielt ein Backup an die im Manifest vermerkten Originalpfade zurueck.
      Der aktuelle Stand wird vorher automatisch gesichert.
    #>
    param($Backup, [switch]$NoSafetyCopy)
    $check = Test-KersBackup -Backup $Backup
    if (-not $check.Valid) {
        Write-KersWarn ('Backup unvollstaendig: ' + $check.Changed + ' veraendert, ' + $check.Missing + ' fehlen.')
        if (-not (Read-KersYesNo '  Trotzdem wiederherstellen?' $false)) { return $false }
    }

    if (-not $NoSafetyCopy) {
        $sources = @($Backup.Entries | ForEach-Object { $_.Source } | Select-Object -Unique)
        [void](New-KersBackup -GameId $Backup.GameId -Sources $sources -Label 'vor_wiederherstellung' -Kind 'safety' -Quiet)
    }

    $n = 0; $err = 0
    foreach ($e in $Backup.Entries) {
        $from = Join-Path $Backup.Files $e.Relative
        if (-not (Test-Path -LiteralPath $from)) { continue }
        # Quelle im Manifest ist Datei oder Ordner; der relative Pfad
        # beginnt immer mit dem Namen des gesicherten Elements
        $rootLeaf = Split-Path $e.Source -Leaf
        $rel = $e.Relative
        if ($rel -ieq $rootLeaf) {
            $to = $e.Source
        } else {
            $sub = $rel.Substring($rootLeaf.Length).TrimStart('\', '/')
            $to  = Join-Path $e.Source $sub
        }
        try {
            $parent = Split-Path $to -Parent
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Copy-Item -LiteralPath $from -Destination $to -Force
            $n++
        } catch {
            Write-KersError ($e.Relative + ': ' + $_.Exception.Message)
            $err++
        }
    }
    Write-KersLog ('Restore ' + $Backup.Name + ': ' + $n + ' Dateien, ' + $err + ' Fehler') 'INFO'
    if ($err -eq 0) { Write-KersOk ($n.ToString() + ' Dateien zurueckgespielt') }
    else            { Write-KersWarn ($n.ToString() + ' Dateien zurueckgespielt, ' + $err + ' Fehler') }
    return ($err -eq 0)
}

function Remove-KersBackup {
    param($Backup)
    try {
        Remove-Item -LiteralPath $Backup.Path -Recurse -Force
        Write-KersLog ('Backup geloescht: ' + $Backup.Path) 'INFO'
        return $true
    } catch {
        Write-KersError ('Loeschen fehlgeschlagen: ' + $_.Exception.Message)
        return $false
    }
}

function Show-KersBackupList {
    param($Backups)
    for ($i = 0; $i -lt $Backups.Count; $i++) {
        $b = $Backups[$i]
        $tag = switch ($b.Kind) { 'profile' { '[Profil]' } 'safety' { '[Auto]  ' } default { '        ' } }
        Write-Host ('   {0,2}) {1} {2,-28} {3,4} Dateien   {4}' -f ($i + 1), $tag, $b.Name, $b.Entries.Count, $b.Created)
        if ($b.Note) { Write-Host ('        ' + $b.Note) -ForegroundColor DarkGray }
    }
}
