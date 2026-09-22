# Architektur

```
KERS_Mods/
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
│   │   ├── GameActions.ps1           generisches Sichern/Wiederherstellen/Diagnose
│   │   ├── Diagnostics.ps1           System- und Spielinfos
│   │   └── games.json                welche Spiele es gibt und wo sie liegen
│   │
│   ├── Plugins/                      pro Spiel eine Datei
│   │   ├── F1.ps1
│   │   └── AssettoCorsa.ps1
│   │
│   └── KERS_Mod_Manager/
│       ├── KERS_Mod_Manager.cmd      Doppelklick-Starter
│       └── manager.ps1               Menues und Ablauf
│
└── docs/
```

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

Ein Treffer zaehlt nur, wenn die in `games.json` hinterlegte Marker-Datei
bzw. der Marker-Ordner darin liegt (z.B. `actionmaps` bei F1,
`AssettoCorsa.exe` bei Assetto Corsa).

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
