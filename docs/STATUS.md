# Stand der Dinge

`Stable` = benutzt und getestet, `Beta` = funktioniert, aber wenig erprobt,
`Geplant` = noch nicht gebaut. Was hier nicht als Stable oder Beta steht,
gibt es noch nicht.

## Werkzeuge

| Werkzeug | Stand | Bemerkung |
|---|---|---|
| F1 Mods Installer (Wheel-Fix, Grafik-Preset, Diagnose) | Stable | eigenstaendige .cmd, F1 2015-26 |
| KERS Core (Logger, CLI, Erkennung, Backup) | Beta | getestet gegen Testdaten, noch wenig Praxis |
| KERS Mod Manager | Beta | CLI, erkennt Spiele, Backup/Restore/Diagnose |
| KERS Diagnostics | Beta | System, erkannte Spiele, Backups |
| GUI | Geplant | erst wenn die CLI stabil ist |

## Spiele

| Spiel | Erkennung | Backup/Restore | Eigene Funktionen | Stand |
|---|---|---|---|---|
| F1 2015 - F1 26 | ja | ja | Wheel-Fix, Grafik-Preset, Actionmap-Uebersicht | Stable |
| Assetto Corsa | ja | ja | Controller-/FFB-Profile, Grafik-Profile | Beta |
| Assetto Corsa Competizione | ja | ja | Wheel-/FFB-Profile, Grafik-Profile | Beta |
| Le Mans Ultimate | ja | ja | Wheel-/FFB-Profile, Grafik-/Spiel-Profile | Beta |
| BeamNG.drive | ja | ja | Controller-/Grafik-Profile, Mods an/aus | Beta |
| EA Sports WRC | ja | ja | Wheel-/FFB- und Grafik-Profile | Beta |
| ETS2 / ATS | - | - | - | Geplant |
| Cyberpunk 2077 | - | - | - | Geplant |
| Minecraft | - | - | - | Geplant |
| Marvel Rivals | - | - | - | Geplant |
| GTA V | - | - | - | Geplant |

## Naechste Schritte

1. Die Simracing-Titel auf einem echten Windows-PC gegenpruefen - vor
   allem die Dateinamen in den Konfigurationsordnern.
2. ETS2 und ATS.
3. Gemeinsames Simracing-Profil (ein FFB-Grundsetup ueber mehrere Spiele).
4. Danach die Nicht-Simracing-Titel (Cyberpunk, Minecraft, Marvel Rivals,
   GTA V).

## Bekannte Grenzen

* Die Erkennung ist auf einem Linux-Rechner entwickelt und gegen Testdaten
  geprueft. Steam-, Epic- und Registry-Erkennung laufen erst auf einem
  echten Windows-PC durch den vollen Praxistest.
* Ob F1 seine Tastenbelegung als Datei ablegt oder im Cloud-Savegame, ist
  offen - die Diagnose im F1-Installer beantwortet das.
* Content Manager wird nicht mitgeliefert und nicht automatisch
  heruntergeladen. Das Tool zeigt die offizielle Adresse, oeffnet auf
  Wunsch den Browser und richtet eine bereits heruntergeladene Datei ein.
* Bei Assetto Corsa, ACC, Le Mans Ultimate, BeamNG und EA WRC sind Ordner-
  und Dateinamen
  aus der Dokumentation uebernommen und noch nicht auf einem echten System
  gegengeprueft. Die Plugins sichern deshalb nur, was sie wirklich finden,
  und die Diagnose zeigt den Ist-Zustand - damit faellt sofort auf, wenn
  eine Datei anders heisst.
