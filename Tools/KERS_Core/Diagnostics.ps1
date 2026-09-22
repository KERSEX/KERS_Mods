# =====================================================================
#  KERS Core - Diagnose
#  Zeigt nur, was tatsaechlich ausgelesen wurde. Es werden keine
#  Probleme erfunden und keine Bewertungen behauptet.
# =====================================================================

function Get-KersSystemInfo {
    $info = [ordered]@{}
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $info['Betriebssystem'] = ('{0} (Build {1})' -f $os.Caption.Trim(), $os.BuildNumber)
            $info['Arbeitsspeicher'] = ('{0:N1} GB' -f ($os.TotalVisibleMemorySize / 1MB))
        }
    } catch { }
    try {
        $cpu = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue)
        if ($cpu.Count -gt 0) { $info['Prozessor'] = ($cpu[0].Name).Trim() }
    } catch { }
    try {
        $gpu = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -and ($_.Name -notmatch 'Basic Display|Remote Display|Virtual') })
        foreach ($g in $gpu) {
            $key = 'Grafikkarte'
            if ($info.Contains($key)) { $key = 'Grafikkarte (' + $g.Name + ')' }
            $drv = if ($g.DriverVersion) { ' | Treiber ' + $g.DriverVersion } else { '' }
            $info[$key] = ($g.Name + $drv)
        }
    } catch { }
    $info['PowerShell'] = [string]$PSVersionTable.PSVersion
    if (-not $info.Contains('Betriebssystem')) { $info['Betriebssystem'] = [string][Environment]::OSVersion.VersionString }
    return $info
}

function Show-KersSystemInfo {
    Write-KersHead 'System'
    $info = Get-KersSystemInfo
    foreach ($k in $info.Keys) {
        Write-Host ('   {0,-18} {1}' -f $k, $info[$k]) -ForegroundColor Gray
    }
}

function Show-KersGameDiagnostics {
    param($Instances)
    Write-KersHead 'Erkannte Spiele'
    if ($Instances.Count -eq 0) {
        Write-KersInfo 'Keine unterstuetzten Spiele gefunden.'
        return
    }
    foreach ($i in $Instances) {
        Write-Host ('   ' + $i.Title) -ForegroundColor White
        if ($i.InstallPath) { Write-Host ('       Installation  : ' + $i.InstallPath + '  (' + $i.Source + ')') -ForegroundColor DarkGray }
        else                { Write-Host  '       Installation  : nicht gefunden' -ForegroundColor DarkGray }
        if ($i.UserPath)    { Write-Host ('       Einstellungen : ' + $i.UserPath) -ForegroundColor DarkGray }
        else                { Write-Host  '       Einstellungen : nicht gefunden' -ForegroundColor DarkGray }

        $backups = @(Get-KersBackups -GameId $i.GameId)
        Write-Host ('       Backups       : ' + $backups.Count) -ForegroundColor DarkGray
    }
}

function Get-KersDirReport {
    # Zwei Ebenen eines Ordners als Textzeilen - fuer Plugin-Diagnosen
    param([string]$Path, [int]$MaxFiles = 20)
    $lines = @()
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return @('   (Ordner nicht vorhanden)')
    }
    foreach ($f in (Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue | Select-Object -First $MaxFiles)) {
        $lines += ('   {0,-44} {1,8} Byte   {2}' -f $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd'))
    }
    foreach ($d in (Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)) {
        $n = @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
        $lines += ('   [{0}] {1} Dateien' -f $d.Name, $n)
    }
    if ($lines.Count -eq 0) { $lines += '   (leer)' }
    return $lines
}
