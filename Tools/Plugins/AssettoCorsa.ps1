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

# ---------------------------------------------------------------------
#  Content Manager
#  Fremdprogramm von x4fab zum Verwalten von AC-Mods. KERS liefert es
#  nicht mit und laedt es auch nicht selbst herunter - der Download
#  passiert im Browser, bewusst und sichtbar.
# ---------------------------------------------------------------------
$script:KersCmUrls = @(
    'https://acstuff.club/app/',
    'https://acstuff.ru/app/'
)

function Get-KersAcContentManager {
    param($Inst)
    $cands = @()
    if ($Inst.InstallPath) {
        $cands += (Join-Path $Inst.InstallPath 'Content Manager.exe')
        $cands += (Join-Path $Inst.InstallPath 'Content Manager Safe Mode.exe')
    }
    if ($env:LOCALAPPDATA) {
        $cands += (Join-Path $env:LOCALAPPDATA 'AcTools Content Manager\Content Manager.exe')
    }
    foreach ($folder in @('Desktop', 'MyDocuments')) {
        try {
            $d = [Environment]::GetFolderPath($folder)
            if ($d) { $cands += (Join-Path $d 'Content Manager.exe') }
        } catch { }
    }
    if ($env:USERPROFILE) { $cands += (Join-Path $env:USERPROFILE 'Downloads\Content Manager.exe') }
    foreach ($c in $cands) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

function New-KersDesktopShortcut {
    param([string]$Target, [string]$Name)
    try {
        $desk = [Environment]::GetFolderPath('Desktop')
        if (-not $desk) { return $null }
        $lnk = Join-Path $desk ($Name + '.lnk')
        $sh = New-Object -ComObject WScript.Shell
        $s = $sh.CreateShortcut($lnk)
        $s.TargetPath = $Target
        $s.WorkingDirectory = (Split-Path $Target -Parent)
        $s.Save()
        return $lnk
    } catch {
        Write-KersError ('Verknuepfung fehlgeschlagen: ' + $_.Exception.Message)
        return $null
    }
}

function Invoke-KersAcContentManager {
    param($Ctx, $Inst)
    Write-Host ''
    Write-KersDim 'Content Manager ist ein kostenloses Fremdprogramm (x4fab) zum'
    Write-KersDim 'Verwalten von Assetto-Corsa-Mods: Autos, Strecken, Apps, Presets.'
    Write-KersDim 'Es gehoert nicht zu KERS. KERS laedt nichts herunter und startet'
    Write-KersDim 'das Programm auch nicht - du entscheidest jeden Schritt selbst.'

    while ($true) {
        $cm = Get-KersAcContentManager $Inst
        Write-Host ''
        if ($cm) {
            Write-KersOk ('Gefunden: ' + $cm)
            Write-KersDim ('Stand: ' + (Get-Item -LiteralPath $cm).LastWriteTime.ToString('yyyy-MM-dd'))
        } else {
            Write-KersInfo 'Content Manager wurde auf diesem Rechner nicht gefunden.'
        }

        $items = @(
            @{ Key = '1'; Text = 'Download-Seite im Browser oeffnen'; Hint = $script:KersCmUrls[0] },
            @{ Key = '2'; Text = 'Heruntergeladene Content Manager.exe einrichten'; Hint = 'kopiert sie in den Assetto-Corsa-Ordner' },
            @{ Key = '3'; Text = 'Verknuepfung auf dem Desktop anlegen' },
            @{ Separator = $true },
            @{ Key = '0'; Text = 'zurueck' }
        )
        Show-KersMenu $items
        $sel = Read-KersKey '  Auswahl' @('1', '2', '3', '0') '0'

        switch ($sel) {
            '0' { return }
            '1' {
                Write-Host ''
                foreach ($u in $script:KersCmUrls) { Write-KersDim $u }
                Write-KersDim 'Bitte im Browser pruefen, dass es die offizielle Seite ist.'
                if (-not (Read-KersYesNo '  Erste Adresse jetzt im Browser oeffnen?' $true)) { continue }
                try {
                    Start-Process $script:KersCmUrls[0]
                    Write-KersOk 'Browser geoeffnet.'
                    Write-KersLog 'Content-Manager-Downloadseite geoeffnet' 'INFO'
                } catch {
                    Write-KersError ('Konnte den Browser nicht oeffnen: ' + $_.Exception.Message)
                }
            }
            '2' {
                if (-not $Inst.InstallPath) {
                    Write-KersWarn 'Der Assetto-Corsa-Ordner ist nicht bekannt - Einrichten nicht moeglich.'
                    continue
                }
                $src = Read-KersText '  Pfad zur heruntergeladenen Content Manager.exe'
                if (-not $src) { continue }
                if (-not (Test-Path -LiteralPath $src)) { Write-KersError 'Datei nicht gefunden.'; continue }
                if ([IO.Path]::GetExtension($src) -ne '.exe') { Write-KersError 'Das ist keine .exe-Datei.'; continue }
                $dest = Join-Path $Inst.InstallPath 'Content Manager.exe'
                if (Test-Path -LiteralPath $dest) {
                    [void](New-KersBackup -GameId $Inst.GameId -Sources @($dest) -Label 'content_manager_alt' -Kind 'backup' -Quiet)
                    Write-KersDim 'Vorhandene Datei gesichert.'
                }
                try {
                    Copy-Item -LiteralPath $src -Destination $dest -Force
                    Write-KersOk ('Kopiert nach: ' + $dest)
                    Write-KersLog ('Content Manager eingerichtet: ' + $dest) 'INFO'
                    Write-KersDim 'Beim ersten Start fragt Content Manager nach dem AC-Ordner.'
                    Write-KersDim 'Mods liegen danach unter assettocorsa\content\cars bzw. \tracks.'
                } catch {
                    Write-KersError ('Kopieren fehlgeschlagen: ' + $_.Exception.Message)
                }
            }
            '3' {
                $cm = Get-KersAcContentManager $Inst
                if (-not $cm) { Write-KersWarn 'Erst einrichten - es wurde keine Content Manager.exe gefunden.'; continue }
                $lnk = New-KersDesktopShortcut -Target $cm -Name 'Content Manager'
                if ($lnk) { Write-KersOk ('Verknuepfung angelegt: ' + $lnk) }
            }
        }
    }
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
    $actions += [pscustomobject]@{
        Text = 'Content Manager einrichten (Mod-Verwaltung)'
        Hint = 'Fremdprogramm - Download im Browser, Installation auf Wunsch'
        Run  = { param($Ctx, $Inst) Invoke-KersAcContentManager $Ctx $Inst }
    }

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
            $cm = Get-KersAcContentManager $Inst
            $lines += ('   Content Manager : ' + $(if ($cm) { $cm } else { 'nicht gefunden' }))
            if ($Inst.InstallPath) {
                foreach ($what in @('cars', 'tracks')) {
                    $p = Join-Path $Inst.InstallPath ('content\' + $what)
                    if (Test-Path -LiteralPath $p) {
                        $n = @(Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue).Count
                        $lines += ('   content\{0,-7} : {1} Eintraege' -f $what, $n)
                    }
                }
            }
            $lines += ('   KERS-Profile    : ' + @(Get-KersBackups -GameId $Inst.GameId -Kind 'profile').Count)
            return $lines
        }
    }
}
