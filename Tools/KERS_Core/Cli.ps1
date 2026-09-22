# =====================================================================
#  KERS Core - einheitliche Konsolen-Oberflaeche
#  Exit-Codes: 0 = ok, 1 = Fehler, 2 = Abbruch durch Benutzer,
#              3 = nichts gefunden
# =====================================================================

$script:KersExitOk       = 0
$script:KersExitError    = 1
$script:KersExitAbort    = 2
$script:KersExitNotFound = 3
$script:KersNullReads    = 0

function Write-KersBanner {
    param([string]$Title, [string]$Subtitle = '')
    try { Clear-Host } catch { }
    Write-Host ''
    Write-Host '  ==============================================================' -ForegroundColor Cyan
    Write-Host ('   ' + $Title) -ForegroundColor White
    if ($Subtitle) { Write-Host ('   ' + $Subtitle) -ForegroundColor Gray }
    Write-Host '  ==============================================================' -ForegroundColor Cyan
}

function Write-KersHead {
    param([string]$Text)
    Write-Host ''
    Write-Host ('  ' + $Text) -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * $Text.Length)) -ForegroundColor DarkCyan
}

function Write-KersOk    { param([string]$T) Write-Host ('  [OK] ' + $T) -ForegroundColor Green }
function Write-KersInfo  { param([string]$T) Write-Host ('  [i] ' + $T) -ForegroundColor Gray }
function Write-KersWarn  { param([string]$T) Write-Host ('  [!] ' + $T) -ForegroundColor Yellow; Write-KersLog $T 'WARN' }
function Write-KersError { param([string]$T) Write-Host ('  [FEHLER] ' + $T) -ForegroundColor Red; Write-KersLog $T 'ERROR' }
function Write-KersDim   { param([string]$T) Write-Host ('  ' + $T) -ForegroundColor DarkGray }

function Read-KersLine {
    # Read-Host liefert $null, wenn keine Eingabe mehr moeglich ist
    # (geschlossene Konsole / umgeleitetes stdin) - das darf keine
    # Endlosschleife geben.
    $v = $null
    try { $v = Read-Host } catch { $v = $null }
    if ($null -eq $v) {
        $script:KersNullReads++
        if ($script:KersNullReads -ge 3) { throw 'Keine Eingabe moeglich - Abbruch.' }
        return ''
    }
    $script:KersNullReads = 0
    return [string]$v
}

function Read-KersKey {
    # erwartet eine der uebergebenen Tasten (Ziffern oder Buchstaben)
    param([string]$Prompt, [string[]]$Valid, [string]$Default = '')
    while ($true) {
        Write-Host ''
        if ($Default) { Write-Host ("$Prompt [$Default] : ") -NoNewline -ForegroundColor Yellow }
        else          { Write-Host ("$Prompt : ")            -NoNewline -ForegroundColor Yellow }
        $raw = (Read-KersLine).Trim()
        if ($raw -eq '' -and $Default) { return $Default }
        foreach ($v in $Valid) {
            if ($raw -ieq $v) { return $v.ToUpper() }
        }
        Write-Host ('  Moeglich: ' + ($Valid -join ', ')) -ForegroundColor Red
    }
}

function Read-KersYesNo {
    param([string]$Prompt, [bool]$Default = $true)
    $hint = if ($Default) { '[J/n]' } else { '[j/N]' }
    while ($true) {
        Write-Host ''
        Write-Host ("$Prompt $hint : ") -NoNewline -ForegroundColor Yellow
        $raw = (Read-KersLine).Trim().ToLower()
        if ($raw -eq '') { return $Default }
        if ($raw -in @('j', 'ja', 'y', 'yes')) { return $true }
        if ($raw -in @('n', 'nein', 'no'))     { return $false }
        Write-Host '  Bitte J oder N.' -ForegroundColor Red
    }
}

function Read-KersText {
    param([string]$Prompt, [string]$Default = '')
    Write-Host ''
    Write-Host ("$Prompt : ") -NoNewline -ForegroundColor Yellow
    $raw = (Read-KersLine).Trim().Trim('"')
    if ($raw -eq '') { return $Default }
    return $raw
}

function Show-KersMenu {
    # Items: @( @{ Key='1'; Text='...'; Hint='...' }, @{ Separator=$true } )
    param([object[]]$Items)
    Write-Host ''
    foreach ($i in $Items) {
        if ($i.Separator) { Write-Host '' ; continue }
        if ($i.Heading)   { Write-Host ('   ' + $i.Heading) -ForegroundColor DarkGray ; continue }
        $line = '   {0,2}) {1}' -f $i.Key, $i.Text
        Write-Host $line -ForegroundColor White
        if ($i.Hint) { Write-Host ('        ' + $i.Hint) -ForegroundColor DarkGray }
    }
}

function ConvertTo-KersSafeName {
    param([string]$Text)
    $x = ($Text -replace '[^A-Za-z0-9_\-\.]', '_')
    while ($x -match '__') { $x = $x -replace '__', '_' }
    $x = $x.Trim('_')
    if ($x -eq '') { $x = 'unbenannt' }
    return $x
}
