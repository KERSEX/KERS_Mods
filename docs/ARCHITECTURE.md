# Architektur

```
KERS_Mods/
├── KERS_Start.cmd                   Einzel-Download: holt und startet alles
│
├── F1/                              Alles rund um die F1-Spiele
│   ├── KERS_F1_Mods_Installer.cmd   eigenstaendig, laeuft auch ohne den Rest
│   ├── presets/                      mitgelieferte Grafik-Presets
│   └── legacy/                       erste Einzel-Skripte (F1 2021)
│
├── Tools/
│   ├── KERS_Core/                    gemeinsame Bausteine
│   │   ├── Logger.ps1                Logdatei, Level DEBUG/INFO/WARN/ERROR
│   │   ├── Cli.ps1                   Banner, Menues, Eingaben, Exit-Codes
│   │   ├── GameDetector.ps1          Steam/Epic/Registry/Ordner/Benutzerordner
│   │   ├── BackupManager.ps1         Backup, Restore, SHA256-Pruefung
│   │   ├── SimRacing.ps1             Profil-Menues, INI-/JSON-Leser
│   │   ├── ModManager.ps1            Mods an/aus (verschieben statt loeschen)
│   │   ├── GameActions.ps1           generisches Sichern/Wiederherstellen/Diagnose
│   │   ├── Diagnostics.ps1           System- und Spielinfos
│   │   └── games.json                welche Spiele es gibt und wo sie liegen
│   │
│   ├── Plugins/                      pro Spiel eine Datei
│   │   ├── F1.ps1
│   │   ├── AssettoCorsa.ps1
│   │   ├── AssettoCorsaCompetizione.ps1
│   │   ├── LeMansUltimate.ps1
│   │   ├── BeamNG.ps1
│   │   ├── EaWrc.ps1
│   │   ├── ScsSoftware.ps1           ETS2 und ATS teilen sich ein Plugin
│   │   ├── Cyberpunk2077.ps1
│   │   ├── Minecraft.ps1
│   │   ├── MarvelRivals.ps1
│   │   └── GtaV.ps1
│   │
│   └── KERS_Mod_Manager/
│       ├── KERS_Mod_Manager.cmd      Doppelklick-Starter
│       └── manager.ps1               Menues und Ablauf
│
└── docs/
```

## Der Starter

`KERS_Start.cmd` ist die einzige Datei, die man braucht. Batch-Teil und
PowerShell-Teil stecken in einer Datei, damit ein Doppelklick genuegt -
eine `.ps1` wuerde Windows sonst im Editor oeffnen.

```
KERS_Start.cmd
   ├── fragt nach Administrator-Rechten (Start-Process -Verb RunAs)
   ├── sucht den Werkzeugkasten
   │      1. neben sich selbst (geklontes/entpacktes Repository)
   │      2. %LOCALAPPDATA%\KERS_Mods\app
   ├── laedt ihn sonst nach Rueckfrage von GitHub
   │      github.com/KERSEX/KERS_Mods/archive/refs/heads/main.zip
   │      -> ZIP pruefen (Groesse + PK-Signatur) -> entpacken -> app\
   │      -> .kers_version.json mit Datum und Commit-SHA
   └── startet Mod Manager oder F1 Installer
```

Der Update-Vergleich fragt `api.github.com` nach dem aktuellen Commit und
vergleicht ihn mit dem gespeicherten SHA. Heruntergeladen wird immer nur
das Projekt-Archiv, ausgefuehrt wird daraus nichts - es werden Dateien
entpackt, mehr nicht.

Adminrechte fragt auch der Mod Manager an (Menuepunkt `E`) und der
F1-Installer beim Start. Noetig sind sie nur fuer Schreibzugriffe in
`Program Files`; alles, was Benutzer-Einstellungen betrifft, laeuft ohne.

## Warum PowerShell und nicht Python

Der Ausgangsplan sah Python vor. Auf einem Gaming-PC ist Python aber nicht
installiert, PowerShell dagegen immer. Da alle Aufgaben hier Dateien,
Registry und XML/INI betreffen und keine Bibliotheken brauchen, laeuft der
Werkzeugkasten ohne jede Abhaengigkeit - herunterladen, doppelklicken,
fertig. Sollte spaeter etwas dazukommen, das Python wirklich braucht
(Bildverarbeitung, Telemetrie-Auswertung, GUI), kann das als eigenes Tool
danebenstehen, ohne den Kern anzufassen.

## Ablauf im Mod Manager

```
KERS_Mod_Manager.cmd
   └── manager.ps1
         ├── laedt KERS_Core/*.ps1
         ├── liest games.json
         ├── GameDetector  -> Instanzen (Titel, Installations-, Benutzerordner)
         ├── Hauptmenue    -> Spiel auswaehlen
         └── Spielmenue
               ├── Aktionen aus dem Plugin (spielspezifisch)
               └── Sichern / Wiederherstellen / Diagnose (aus dem Core)
```

Ein Spiel taucht im Menue auf, sobald es in `games.json` steht und erkannt
wurde. Ein Plugin ist optional: ohne Plugin gibt es Backup, Restore und
Diagnose trotzdem.

## Erkennung

`GameDetector.ps1` sucht in dieser Reihenfolge und ohne feste
Laufwerksbuchstaben:

1. Steam-Bibliotheken aus der Registry und `libraryfolders.vdf`
2. `SteamLibrary`, `Steam`, `Games\SteamLibrary` auf allen festen Laufwerken
3. EA-, Origin-, Epic- und Programme-Ordner auf allen festen Laufwerken
4. Epic-Manifeste unter `ProgramData\Epic\...\Manifests`
5. Deinstallations-Eintraege der Registry (Name per Muster aus games.json)
6. Benutzerordner (`%DOCS%`, `%LOCALAPPDATA%`, `%APPDATA%` ...)
7. `user.fromInstall` fuer Spiele, die ihre Konfiguration im
   Installationsordner ablegen (Le Mans Ultimate: `UserData`)
8. `user.childSelect: "latest"` fuer Spiele mit einem Ordner je Version
   (BeamNG) - genommen wird der zuletzt benutzte, nicht jeder als eigenes
   Spiel wie bei den F1-Jahrgaengen

Ein Treffer zaehlt nur, wenn die in `games.json` hinterlegte Marker-Datei
bzw. der Marker-Ordner darin liegt (z.B. `actionmaps` bei F1,
`AssettoCorsa.exe` bei Assetto Corsa).

## Gemeinsame Simracing-Bausteine

Assetto Corsa, ACC und Le Mans Ultimate machen dasselbe: eine Handvoll
Konfigurationsdateien als benanntes Profil ablegen und zurueckholen. Der
Ablauf steht einmal in `SimRacing.ps1`; ein Plugin sagt nur noch, welche
Dateien dazugehoeren:

```powershell
$actions += New-KersProfileActions -GetFiles ${function:Get-KersAccControlFiles} `
                                   -Label 'Wheel-/FFB-Profil' -Tag 'ctrl' `
                                   -Examples 'MOZA_R5_GT3, LowForce'
```

Daraus entstehen die drei Menuepunkte Speichern / Laden / Verwalten, samt
Sicherheitskopie und SHA256-Pruefung aus dem Backup-Manager. Ein Spiel kann
mehrere Gruppen haben (z.B. Controller und Grafik), unterschieden ueber
`-Tag`.

## Mods an- und abschalten

Fuenf Spiele brauchen dasselbe, also steht es einmal in `ModManager.ps1`:

```powershell
$actions += New-KersModActions -GetDirs ${function:Get-KersScsModDirs} -Label 'Mods'
```

`GetDirs` liefert nur `@{ Active = ...; Disabled = ...; Filters = @('*.scs') }`.
Deaktivieren verschiebt die Datei in den `_disabled_kers`-Ordner daneben,
Aktivieren holt sie zurueck. Es wird nie etwas geloescht, und der Spiel-
Ordner bleibt sonst unangetastet.

## Backups

```
%LOCALAPPDATA%\KERS_Mods\
├── backups\<spiel>\<datum_zeit>_<label>\
│   ├── backup.json     Quelle, Groesse und SHA256 jeder Datei
│   └── files\...       die Kopien
└── logs\KERS_ModManager.log
```

Drei Arten, unterschieden im Manifest (`kind`):

| kind | entsteht | sichtbar als |
|---|---|---|
| `backup` | manuell ueber das Menue | normaler Eintrag |
| `profile` | benannte Profile eines Plugins | `[Profil]` |
| `safety` | automatisch vor jedem Wiederherstellen | `[Auto]` |

`Restore-KersBackup` prueft vor dem Zurueckspielen die SHA256-Summen und
legt den aktuellen Stand als `safety`-Backup ab. Zurueckgeschrieben wird
immer an die im Manifest vermerkten Originalpfade - nie irgendwo anders hin.

## Exit-Codes

| Code | Bedeutung |
|---|---|
| 0 | alles in Ordnung |
| 1 | Fehler |
| 2 | Abbruch durch den Benutzer |
| 3 | nichts gefunden |
