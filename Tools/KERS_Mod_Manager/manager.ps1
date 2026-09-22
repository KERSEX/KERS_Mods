# =====================================================================
#  KERS Mod Manager
#  Erkennt unterstuetzte Spiele und stellt die passenden KERS-Werkzeuge
#  bereit. Spiele kommen aus Tools/KERS_Core/games.json, spielspezifische
#  Funktionen aus Tools/Plugins.
# =====================================================================
[CmdletBinding()]
param(
    [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
    [string]$LogLevel = 'INFO'
)

$ErrorActionPreference = 'Stop'
$script:KersVersion = '0.1.0'

$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolsDir = Split-Path -Parent $here
$repoRoot = Split-Path -Parent $toolsDir
$coreDir  = Join-Path $toolsDir 'KERS_Core'
$plugDir  = Join-Path $toolsDir 'Plugins'

foreach ($m in @('Logger.ps1', 'Cli.ps1', 'GameDetector.ps1', 'BackupManager.ps1', 'Diagnostics.ps1', 'GameActions.ps1')) {
    $f = Join-Path $coreDir $m
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Host ('  [FEHLER] Core-Datei fehlt: ' + $f) -ForegroundColor Red
        exit 1
    }
    . $f
}

[void](Initialize-KersLog -Name 'KERS_ModManager' -Level $LogLevel)
Write-KersLog ('Mod Manager ' + $script:KersVersion + ' | Repo: ' + $repoRoot) 'INFO'

$script:Ctx = [pscustomobject]@{
    RepoRoot = $repoRoot
    ToolsDir = $toolsDir
    CoreDir  = $coreDir
    Version  = $script:KersVersion
}

function Get-KersPluginFor {
    param($Def)
    if (-not $Def -or -not $Def.id) { return $null }
    if ($script:Plugins.ContainsKey($Def.id)) { return $script:Plugins[$Def.id] }
    return $null
}

function Get-KersGamesJsonPath {
    # KERS_GAMES_JSON erlaubt eigene Spiel-Definitionen (z.B. zum Testen)
    if ($env:KERS_GAMES_JSON -and (Test-Path -LiteralPath $env:KERS_GAMES_JSON)) {
        Write-KersLog ('Eigene games.json: ' + $env:KERS_GAMES_JSON) 'INFO'
        return $env:KERS_GAMES_JSON
    }
    return (Join-Path $coreDir 'games.json')
}

function Get-KersAllInstances {
    $all = @()
    foreach ($d in $script:GameDefs) {
        foreach ($i in (Get-KersGameInstances $d)) { $all += $i }
    }
    return @($all | Sort-Object GameName, Title)
}

# ---------------------------------------------------------------------
#  Menues
# ---------------------------------------------------------------------
function Show-KersGameMenu {
    param($Inst)
    $plugin = Get-KersPluginFor $Inst.Definition
    while ($true) {
        Write-KersBanner ('KERS | ' + $Inst.Title.ToUpper()) $Inst.GameName
        $items = @()
        $keys  = @()
        $n = 0
        if ($plugin -and $plugin.Actions) {
            foreach ($a in $plugin.Actions) {
                $n++
                $items += @{ Key = "$n"; Text = $a.Text; Hint = $a.Hint }
                $keys  += "$n"
            }
            $items += @{ Separator = $true }
        }
        $items += @{ Heading = 'Immer verfuegbar' }
        $items += @{ Key = 'B'; Text = 'Einstellungen sichern' }
        $items += @{ Key = 'R'; Text = 'Backup wiederherstellen' }
        $items += @{ Key = 'D'; Text = 'Diagnose' }
        $items += @{ Separator = $true }
        $items += @{ Key = '0'; Text = 'zurueck' }
        $keys  += @('B', 'R', 'D', '0')

        Show-KersMenu $items
        $sel = Read-KersKey '  Auswahl' $keys '0'

        switch ($sel) {
            '0' { return }
            'B' { Invoke-KersBackupAction $Inst }
            'R' { Invoke-KersRestoreAction $Inst }
            'D' { Invoke-KersGameDiagnostics -Inst $Inst -Plugin $plugin -Ctx $script:Ctx }
            default {
                $idx = [int]$sel - 1
                $action = $plugin.Actions[$idx]
                Write-KersHead $action.Text
                try {
                    & $action.Run $script:Ctx $Inst
                } catch {
                    Write-KersError $_.Exception.Message
                }
            }
        }
        Write-Host ''
        Write-Host '  Weiter mit Enter ...' -NoNewline -ForegroundColor DarkGray
        [void](Read-KersLine)
    }
}

function Show-KersMainMenu {
    while ($true) {
        Write-KersBanner 'KERS MOD MANAGER' ('v' + $script:KersVersion + '   |   github.com/KERSEX/KERS_Mods')
        Write-Host ''
        Write-Host '  Suche installierte Spiele ...' -ForegroundColor DarkGray
        $instances = @(Get-KersAllInstances)

        $items = @()
        $keys  = @()
        if ($instances.Count -eq 0) {
            Write-KersWarn 'Kein unterstuetztes Spiel gefunden.'
            Write-KersDim 'Unterstuetzt werden aktuell F1 2015-26 und Assetto Corsa.'
        } else {
            $items += @{ Heading = 'Erkannte Spiele' }
            for ($i = 0; $i -lt $instances.Count; $i++) {
                $inst = $instances[$i]
                $where = if ($inst.InstallPath) { $inst.InstallPath } else { $inst.UserPath }
                $items += @{ Key = [string]($i + 1); Text = $inst.Title; Hint = $where }
                $keys  += [string]($i + 1)
            }
            $items += @{ Separator = $true }
        }
        $items += @{ Heading = 'Werkzeuge' }
        $items += @{ Key = 'D'; Text = 'Diagnose (System, Spiele, Backups)' }
        $items += @{ Key = 'L'; Text = 'Logdatei anzeigen' }
        $items += @{ Separator = $true }
        $items += @{ Key = '0'; Text = 'Beenden' }
        $keys  += @('D', 'L', '0')

        Show-KersMenu $items
        $sel = Read-KersKey '  Auswahl' $keys '0'

        switch ($sel) {
            '0' { return $script:KersExitOk }
            'D' {
                Write-KersBanner 'KERS DIAGNOSTICS' ''
                Show-KersSystemInfo
                Show-KersGameDiagnostics $instances
                Write-Host ''
                Write-Host '  Weiter mit Enter ...' -NoNewline -ForegroundColor DarkGray
                [void](Read-KersLine)
            }
            'L' {
                $log = Get-KersLogFile
                Write-KersHead 'Logdatei'
                if ($log -and (Test-Path -LiteralPath $log)) {
                    Write-KersDim $log
                    foreach ($l in (Get-Content -LiteralPath $log -Tail 20 -ErrorAction SilentlyContinue)) {
                        Write-Host ('   ' + $l) -ForegroundColor DarkGray
                    }
                } else {
                    Write-KersInfo 'Noch keine Logdatei vorhanden.'
                }
                Write-Host ''
                Write-Host '  Weiter mit Enter ...' -NoNewline -ForegroundColor DarkGray
                [void](Read-KersLine)
            }
            default {
                Show-KersGameMenu $instances[[int]$sel - 1]
            }
        }
    }
}

# ---------------------------------------------------------------------
#  Spiel-Definitionen und Plugins laden
#
#  Das Laden der Plugins passiert bewusst hier auf Skript-Ebene: wuerde
#  ein Plugin innerhalb einer Funktion mit . geladen, landeten seine
#  Hilfsfunktionen nur in deren lokalem Gueltigkeitsbereich und waeren
#  beim spaeteren Ausfuehren einer Aktion nicht mehr da.
# ---------------------------------------------------------------------
$script:GameDefs = @()
$script:Plugins  = @{}
try {
    $script:GameDefs = @(Get-KersGameDefinitions -JsonPath (Get-KersGamesJsonPath))
} catch {
    Write-KersError ('games.json konnte nicht gelesen werden: ' + $_.Exception.Message)
    exit $script:KersExitError
}
foreach ($def in $script:GameDefs) {
    if (-not $def.plugin) { continue }
    $pf = Join-Path $plugDir $def.plugin
    if (-not (Test-Path -LiteralPath $pf)) {
        Write-KersLog ('Plugin fehlt: ' + $pf) 'WARN'
        continue
    }
    try {
        . $pf                                   # definiert Get-KersPlugin neu
        $script:Plugins[$def.id] = Get-KersPlugin   # sofort einsammeln
        Write-KersLog ('Plugin geladen: ' + $def.plugin) 'DEBUG'
    } catch {
        Write-KersLog ('Plugin ' + $def.plugin + ' fehlerhaft: ' + $_.Exception.Message) 'ERROR'
    }
}

$exit = $script:KersExitOk
try {
    $exit = Show-KersMainMenu
} catch {
    Write-KersError $_.Exception.Message
    Write-KersLog ('Abbruch: ' + $_.Exception.ToString()) 'ERROR'
    $exit = $script:KersExitError
}
Write-KersLog ('Ende, Exit-Code ' + $exit) 'INFO'
exit $exit
