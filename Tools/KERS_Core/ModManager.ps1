# =====================================================================
#  KERS Core - Mods an- und abschalten
#
#  Immer dasselbe Prinzip, egal ob BeamNG-ZIPs, SCS-Archive,
#  Cyberpunk-.archive oder Minecraft-JARs:
#    aktiv       <Spielordner>\<mods>\
#    deaktiviert <Spielordner>\<mods>_disabled_kers\
#  Deaktivieren heisst verschieben. Geloescht wird nie etwas.
# =====================================================================

function Get-KersModList {
    param([string]$Active, [string]$Disabled, [string[]]$Filters)
    $out = @()
    foreach ($pair in @(@{ D = $Active; E = $true }, @{ D = $Disabled; E = $false })) {
        if (-not $pair.D -or -not (Test-Path -LiteralPath $pair.D)) { continue }
        foreach ($f in $Filters) {
            foreach ($file in (Get-ChildItem -LiteralPath $pair.D -Filter $f -File -ErrorAction SilentlyContinue)) {
                if ($out | Where-Object { $_.Path -eq $file.FullName }) { continue }
                $out += [pscustomobject]@{
                    Name    = $file.Name
                    Path    = $file.FullName
                    Enabled = $pair.E
                    Size    = $file.Length
                }
            }
        }
    }
    return @($out | Sort-Object Name)
}

function New-KersModActions {
    <#
      -GetDirs   Scriptblock, bekommt die Instanz und liefert
                 @{ Active = '<pfad>'; Disabled = '<pfad>'; Filters = @('*.zip') }
      -Label     Menuetext, z.B. 'Mods'
      -Warning   Hinweis, der vor der Liste steht (z.B. Online-Warnung)
    #>
    param(
        [Parameter(Mandatory = $true)][scriptblock]$GetDirs,
        [string]$Label = 'Mods',
        [string]$Hint = '',
        [string]$Warning = ''
    )

    $run = {
        param($Ctx, $Inst)
        $cfg = & $GetDirs $Inst
        if (-not $cfg -or -not $cfg.Active) {
            Write-KersWarn 'Kein Mod-Ordner bekannt.'
            return
        }
        if ($Warning) { Write-Host ''; Write-KersWarn $Warning }
        while ($true) {
            $mods = @(Get-KersModList -Active $cfg.Active -Disabled $cfg.Disabled -Filters $cfg.Filters)
            Write-Host ''
            if ($mods.Count -eq 0) {
                Write-KersInfo ('Keine ' + $Label + ' gefunden.')
                Write-KersDim ('Gesucht in: ' + $cfg.Active)
                return
            }
            $on  = @($mods | Where-Object { $_.Enabled }).Count
            $off = $mods.Count - $on
            Write-Host ('  ' + $Label + ' (' + $on + ' aktiv, ' + $off + ' deaktiviert)') -ForegroundColor White
            for ($i = 0; $i -lt $mods.Count; $i++) {
                $m = $mods[$i]
                $state = if ($m.Enabled) { '[an] ' } else { '[aus]' }
                $col   = if ($m.Enabled) { 'Green' } else { 'DarkGray' }
                Write-Host ('   {0,2}) {1} {2,-44} {3,9:N0} KB' -f ($i + 1), $state, $m.Name, ($m.Size / 1KB)) -ForegroundColor $col
            }
            Write-KersDim 'Nummer schaltet um. Deaktivierte Dateien werden verschoben, nicht geloescht.'
            $keys = @(1..$mods.Count | ForEach-Object { [string]$_ }) + @('0')
            $sel = Read-KersKey '  Auswahl (0 = zurueck)' $keys '0'
            if ($sel -eq '0') { return }

            $m = $mods[[int]$sel - 1]
            $target = if ($m.Enabled) { $cfg.Disabled } else { $cfg.Active }
            try {
                if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                Move-Item -LiteralPath $m.Path -Destination (Join-Path $target $m.Name) -Force
                $what = if ($m.Enabled) { 'deaktiviert' } else { 'aktiviert' }
                Write-KersOk ($m.Name + ' ' + $what)
                Write-KersLog ('Mod ' + $what + ': ' + $m.Path) 'INFO'
            } catch {
                Write-KersError ($m.Name + ': ' + $_.Exception.Message)
            }
        }
    }.GetNewClosure()

    return @([pscustomobject]@{
        Text = $Label + ' aktivieren / deaktivieren'
        Hint = $(if ($Hint) { $Hint } else { 'verschiebt Dateien in einen _disabled_kers-Ordner - nichts wird geloescht' })
        Run  = $run
    })
}

function Get-KersModCounts {
    # kurze Zeile fuer die Diagnose
    param([string]$Active, [string]$Disabled, [string[]]$Filters)
    $mods = @(Get-KersModList -Active $Active -Disabled $Disabled -Filters $Filters)
    $on = @($mods | Where-Object { $_.Enabled }).Count
    return ('' + $on + ' aktiv, ' + ($mods.Count - $on) + ' deaktiviert')
}
