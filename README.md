# KERS_Mods

Werkzeugkasten fuers Modden und Einstellen von Spielen - vor allem
Simracing. Keine fremden Mods, keine Downloads, keine Cheats: nur Tools,
die Konfigurationen setzen, sichern und wiederherstellen.

Alles laeuft mit Bordmitteln von Windows (PowerShell). Nichts zu
installieren, keine Abhaengigkeiten.

## Schnellstart

| Ich will ... | Datei |
|---|---|
| MOZA-Lenkrad in F1 zum Laufen bringen, Grafik-Preset setzen | `F1/KERS_F1_Mods_Installer.cmd` |
| alle unterstuetzten Spiele sehen, sichern, wiederherstellen | `Tools/KERS_Mod_Manager/KERS_Mod_Manager.cmd` |

Repository als ZIP herunterladen (*Code -> Download ZIP*), entpacken,
Datei doppelklicken. Der F1-Installer funktioniert auch allein, wenn man
nur ihn herunterlaedt.

## Unterstuetzte Spiele

| Spiel | Was geht | Stand |
|---|---|---|
| F1 2015 - F1 26 | MOZA Wheel-Fix, Grafik-Preset, Einstellungen sichern, Diagnose | Stable |
| Assetto Corsa | Controller-/FFB- und Grafik-Profile, Sichern, Diagnose | Beta |
| Assetto Corsa Competizione | Wheel-/FFB- und Grafik-Profile, Sichern, Diagnose | Beta |
| Le Mans Ultimate | Wheel-/FFB- und Grafik-Profile, Sichern, Diagnose | Beta |
| BeamNG.drive | Controller-/Grafik-Profile, Mods an- und abschalten | Beta |
| EA Sports WRC | Wheel-/FFB- und Grafik-Profile, Sichern, Diagnose | Beta |

Weitere Titel sind geplant, aber noch nicht gebaut - der ehrliche Stand
steht in [docs/STATUS.md](docs/STATUS.md).

## KERS Mod Manager

```
  ==============================================================
   KERS MOD MANAGER
   v0.1.0   |   github.com/KERSEX/KERS_Mods
  ==============================================================

   Erkannte Spiele
    1) F1 25
        D:\SteamLibrary\steamapps\common\F1 25
    2) Assetto Corsa
        D:\SteamLibrary\steamapps\common\assettocorsa

   Werkzeuge
    D) Diagnose (System, Spiele, Backups)
    L) Logdatei anzeigen

    0) Beenden
```

Bei **Assetto Corsa** gibt es zusaetzlich *Content Manager einrichten*:
das Tool zeigt die offizielle Download-Adresse, oeffnet auf Wunsch den
Browser und richtet eine heruntergeladene `Content Manager.exe` im
Spielordner ein - mit Verknuepfung, wenn gewuenscht. Heruntergeladen oder
gestartet wird nichts ohne dich.

Bei **BeamNG** lassen sich Mods an- und abschalten, ohne sie zu loeschen:
deaktivierte ZIPs wandern nach `mods_disabled_kers\` und jederzeit zurueck.

Profile sind benannte Sicherungen der Konfigurationsdateien: `GT3` mit
starkem FFB, `Regen` mit weniger Gain, `1440p_Performance` fuer die Grafik -
gespeichert, geladen und geprueft ueber denselben Backup-Mechanismus.

Der Manager sucht Spiele in Steam-Bibliotheken, Epic-Manifesten, der
Registry und den ueblichen Ordnern auf allen festen Laufwerken - feste
Laufwerksbuchstaben werden nirgends vorausgesetzt. Jedes erkannte Spiel
bekommt **Sichern**, **Wiederherstellen** und **Diagnose**; spielspezifische
Funktionen kommen aus einem Plugin.

## Backups

```
%LOCALAPPDATA%\KERS_Mods\
├── backups\<spiel>\<datum_zeit>_<label>\
│   ├── backup.json      Quelle, Groesse und SHA256 jeder Datei
│   └── files\...
└── logs\KERS_ModManager.log
```

* Vor jeder Aenderung an Spieldateien wird automatisch gesichert.
* Vor dem Wiederherstellen werden die SHA256-Summen geprueft, und der
  aktuelle Stand wandert vorher in ein `[Auto]`-Backup.
* Zurueckgeschrieben wird nur an die Pfade, die im Manifest stehen.

## Sicherheitsprinzipien

* Backup vor jeder potentiell destruktiven Aktion.
* Geschrieben wird ausschliesslich im Spielordner, im Benutzerordner des
  Spiels und unter `%LOCALAPPDATA%\KERS_Mods`.
* Destruktive Aktionen fragen nach.
* Alles wird protokolliert - ohne Passwoerter, Tokens oder Accountdaten.
* Keine Downloads ohne ausdrueckliche Zustimmung, keine fremden Mods im
  Gepaeck.
* Keine Cheats, keine Anti-Cheat-Umgehung, keine Online-Manipulation.
* Keine "FPS Booster" und keine Performance-Versprechen ohne Messung.

## Entwicklung

* [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Aufbau, Erkennung, Backups,
  Exit-Codes, und warum PowerShell statt Python
* [docs/PLUGINS.md](docs/PLUGINS.md) - ein Spiel hinzufuegen: Eintrag in
  `games.json` plus optionales Plugin
* [docs/STATUS.md](docs/STATUS.md) - was Stable, Beta oder geplant ist
* [F1/README.md](F1/README.md) - der F1-Installer im Detail

Ein neues Spiel braucht keinen Eingriff in den Core: ein Eintrag in
`Tools/KERS_Core/games.json` genuegt fuer Erkennung, Backup und Diagnose,
ein Plugin kommt nur fuer spielspezifische Funktionen dazu.

Pull Requests und Fehlermeldungen sind willkommen - am besten mit der
Ausgabe aus *Diagnose* und dem passenden Ausschnitt aus der Logdatei.

## Lizenz

MIT, siehe [LICENSE](LICENSE).
