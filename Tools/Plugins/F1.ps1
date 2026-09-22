# =====================================================================
#  KERS Plugin - F1 2015 bis F1 26
#
#  Der Wheel-Fix und das Grafik-Preset stecken weiterhin im bewaehrten
#  Installer F1\KERS_F1_Mods_Installer.cmd. Das Plugin startet ihn und
#  ergaenzt Diagnose; Backup/Restore kommen aus dem Core.
# =====================================================================

function Get-KersPlugin {
    return [pscustomobject]@{
        Id      = 'f1'
        Name    = 'F1 (2015-2026)'
        Actions = @(
            [pscustomobject]@{
                Text = 'F1 Mods Installer starten (MOZA Wheel-Fix, Grafik-Preset)'
                Hint = 'oeffnet KERS_F1_Mods_Installer.cmd in einem eigenen Fenster'
                Run  = {
                    param($Ctx, $Inst)
                    $cmd = Join-Path $Ctx.RepoRoot 'F1\KERS_F1_Mods_Installer.cmd'
                    if (-not (Test-Path -LiteralPath $cmd)) {
                        Write-KersError ('Nicht gefunden: ' + $cmd)
                        return
                    }
                    Write-KersInfo 'Der Installer laeuft in einem eigenen Fenster.'
                    Write-KersLog ('Starte ' + $cmd) 'INFO'
                    try {
                        Start-Process -FilePath $env:ComSpec -ArgumentList @('/c', $cmd) -Wait
                        Write-KersOk 'Installer beendet.'
                    } catch {
                        Write-KersError $_.Exception.Message
                    }
                }
            },
            [pscustomobject]@{
                Text = 'Installierte KERS-Actionmaps anzeigen'
                Run  = {
                    param($Ctx, $Inst)
                    if (-not $Inst.InstallPath) {
                        Write-KersWarn 'Installationsordner unbekannt - nichts zu pruefen.'
                        return
                    }
                    $am = Join-Path $Inst.InstallPath 'actionmaps'
                    $mine = @(Get-ChildItem -LiteralPath $am -Filter '*.xml' -File -ErrorAction SilentlyContinue |
                              Where-Object { $_.Name -match '^(KERS_|moza_)' })
                    if ($mine.Count -eq 0) {
                        Write-KersInfo 'Keine KERS-Actionmap installiert.'
                        return
                    }
                    foreach ($f in $mine) {
                        Write-Host ('   ' + $f.Name + '   ' + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) -ForegroundColor Gray
                    }
                }
            }
        )
        Diagnostics = {
            param($Ctx, $Inst)
            $lines = @()
            if ($Inst.InstallPath) {
                $am = Join-Path $Inst.InstallPath 'actionmaps'
                $all = @(Get-ChildItem -LiteralPath $am -Filter '*.xml' -File -ErrorAction SilentlyContinue)
                $mine = @($all | Where-Object { $_.Name -match '^(KERS_|moza_)' })
                $lines += ('   actionmaps      : ' + $all.Count + ' Profile, davon ' + $mine.Count + ' von KERS')
                foreach ($f in $mine) { $lines += ('      ' + $f.Name) }
            }
            if ($Inst.UserPath) {
                $hw = Join-Path $Inst.UserPath 'hardwaresettings\hardware_settings_config.xml'
                if (Test-Path -LiteralPath $hw) {
                    $lines += ('   Grafik-Config   : vorhanden (' + (Get-Item -LiteralPath $hw).LastWriteTime.ToString('yyyy-MM-dd') + ')')
                    try {
                        $x = New-Object System.Xml.XmlDocument
                        $x.Load($hw)
                        $res = $x.DocumentElement.SelectSingleNode('graphics_card/resolution')
                        if ($res) {
                            $lines += ('   Aufloesung      : ' + $res.get_Attributes()['width'].Value + 'x' + $res.get_Attributes()['height'].Value)
                        }
                        $udp = $x.DocumentElement.SelectSingleNode('motion/udp')
                        if ($udp -and $udp.get_Attributes()['enabled']) {
                            $lines += ('   UDP-Telemetrie  : ' + $udp.get_Attributes()['enabled'].Value)
                        }
                    } catch { }
                } else {
                    $lines += '   Grafik-Config   : nicht vorhanden (Spiel noch nie gestartet?)'
                }
            }
            return $lines
        }
    }
}
