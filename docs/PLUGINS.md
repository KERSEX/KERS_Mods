# Ein Spiel hinzufuegen

Zwei Schritte: Eintrag in `Tools/KERS_Core/games.json`, optional ein Plugin
unter `Tools/Plugins`. Am Core muss dafuer nichts geaendert werden.

## 1. Eintrag in games.json

```json
{
  "id": "assetto_corsa",
  "name": "Assetto Corsa",
  "status": "beta",
  "plugin": "AssettoCorsa.ps1",
  "install": {
    "folderNames": ["assettocorsa"],
    "folderPattern": "^F1[ _\\-]?(2024|25|26)$",
    "registryNames": ["^Assetto Corsa$"],
    "marker": "AssettoCorsa.exe"
  },
  "user": {
    "paths": ["%DOCS%\\Assetto Corsa"],
    "childPattern": null
  },
  "backup": ["cfg"]
}
```

| Feld | Bedeutung |
|---|---|
| `id` | interner Name, auch Ordnername der Backups |
| `status` | `stable`, `beta` oder `planned` |
| `plugin` | Dateiname unter `Tools/Plugins` (weglassen = nur Core-Funktionen) |
| `install.folderNames` | exakte Ordnernamen |
| `install.folderPattern` | Regex fuer Ordnernamen (z.B. mehrere Jahrgaenge) |
| `install.registryNames` | Regex-Liste fuer `DisplayName` der Deinstallations-Eintraege |
| `install.marker` | Datei/Ordner, der im Spielordner liegen muss |
| `user.paths` | Benutzerordner, Platzhalter `%DOCS%`, `%LOCALAPPDATA%`, `%APPDATA%`, `%USERPROFILE%`, `%PROGRAMDATA%` |
| `user.childPattern` | Regex, wenn unterhalb je Jahrgang ein eigener Ordner liegt |
| `user.fromInstall` | Unterordner im Spielordner, wenn die Konfiguration dort liegt (z.B. `UserData`) |
| `user.childSelect` | `latest` nimmt nur den zuletzt benutzten Unterordner (Versionsordner wie bei BeamNG) statt jeden als eigenes Spiel |
| `backup` | Unterordner/Dateien im Benutzerordner, die gesichert werden |

Ohne Plugin bekommt das Spiel bereits Sichern, Wiederherstellen und
Diagnose.

Zum Ausprobieren eigener Definitionen, ohne die mitgelieferte Datei
anzufassen: Umgebungsvariable `KERS_GAMES_JSON` auf die eigene Datei
setzen, der Manager nimmt dann diese.

## 2. Plugin

Eine Datei mit genau einer Funktion `Get-KersPlugin`:

```powershell
function Get-KersPlugin {
    return [pscustomobject]@{
        Id      = 'assetto_corsa'
        Name    = 'Assetto Corsa'
        Actions = @(
            [pscustomobject]@{
                Text = 'Controller-Profil speichern'
                Hint = 'optionale zweite Zeile im Menue'
                Run  = {
                    param($Ctx, $Inst)
                    # ... hier passiert die Arbeit
                }
            }
        )
        Diagnostics = {
            param($Ctx, $Inst)
            return @('   Zeile fuer die Diagnose')
        }
    }
}
```

`$Inst` ist die erkannte Spiel-Instanz:

| Feld | Inhalt |
|---|---|
| `Title` | z.B. `F1 25` oder `Assetto Corsa` |
| `InstallPath` | Spielordner oder `$null` |
| `UserPath` | Benutzerordner oder `$null` |
| `GameId` | `id` aus games.json |
| `Definition` | der komplette games.json-Eintrag |

`$Ctx.RepoRoot` zeigt auf das Repository, damit ein Plugin mitgelieferte
Dateien finden kann.

## Profile ohne eigenen Code

Fuer den haeufigsten Fall - eine Gruppe Konfigurationsdateien als
benanntes Profil - gibt es eine Fabrik. Sie liefert die drei Menuepunkte
Speichern, Laden und Verwalten fertig zurueck:

```powershell
function Get-KersAccControlFiles {
    param($Inst)
    return (Get-KersExistingPaths -Base (Join-Path $Inst.UserPath 'Config') `
                                  -Names @('controls.json', 'ffbSettings.json'))
}

function Get-KersPlugin {
    $actions = @()
    $actions += New-KersProfileActions -GetFiles ${function:Get-KersAccControlFiles} `
                                       -Label 'Wheel-/FFB-Profil' -Tag 'ctrl' `
                                       -Examples 'MOZA_R5_GT3'
    return [pscustomobject]@{ Id = 'acc'; Name = 'Assetto Corsa Competizione'; Actions = $actions }
}
```

`-Tag` trennt mehrere Gruppen eines Spiels (Controller, Grafik ...), damit
beim Laden nur die passenden Eintraege auftauchen. Nicht vorhandene Dateien
werden uebersprungen - so laeuft dasselbe Plugin auch, wenn eine
Spielversion eine Datei anders nennt.

## Was dem Plugin zur Verfuegung steht

```powershell
New-KersBackup -GameId <id> -Sources <pfade> -Label <name> [-Kind backup|profile|safety] [-Note ..] [-Quiet]
Get-KersBackups -GameId <id> [-Kind ..]
Restore-KersBackup -Backup <objekt> [-NoSafetyCopy]
Test-KersBackup -Backup <objekt>       # SHA256-Pruefung
Remove-KersBackup -Backup <objekt>
Show-KersBackupList $backups

Write-KersHead / Write-KersOk / Write-KersInfo / Write-KersWarn / Write-KersError / Write-KersDim
Read-KersText / Read-KersKey / Read-KersYesNo / Read-KersLine
Show-KersMenu
Write-KersLog <text> [DEBUG|INFO|WARN|ERROR]
ConvertTo-KersSafeName <text>
Expand-KersPath '%DOCS%\...'

New-KersProfileActions -GetFiles <scriptblock> -Label <text> [-Tag ..] [-Examples ..] [-Hint ..]
Get-KersExistingPaths -Base <ordner> -Names <namen>   # nur real vorhandene Pfade
Get-KersIniValue  -Path <datei> -Key 'FF_GAIN'
Get-KersJsonValue -Path <datei> -Dotted 'Force Feedback.FFB Device Name'
```

## Regeln fuer Plugins

* Alle Plugins teilen sich beim Laden denselben Gueltigkeitsbereich.
  Hilfsfunktionen deshalb eindeutig benennen (`Get-KersAcControlPaths`,
  nicht `Get-Paths`), sonst ueberschreibt ein Plugin das andere.
* Vor jeder Aenderung an Spieldateien ein Backup anlegen
  (`New-KersBackup`, oder `Restore-KersBackup`, das es selbst tut).
* Nur innerhalb von `InstallPath`, `UserPath` und dem KERS-Datenordner
  schreiben.
* Fehler abfangen und melden, statt das Menue abstuerzen zu lassen.
* Keine Downloads ohne ausdrueckliche Zustimmung, keine fremden Mods
  mitliefern, keine Cheats oder Eingriffe in Anti-Cheat. Fremdprogramme
  (Beispiel Content Manager) werden nur benannt, verlinkt und auf Wunsch
  eingerichtet - nie im Hintergrund geladen oder gestartet.
* Deaktivieren heisst verschieben, nicht loeschen (Beispiel BeamNG-Mods).
* Keine Passwoerter, Tokens oder Accountdaten speichern oder loggen.
