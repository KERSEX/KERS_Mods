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
| Assetto Corsa | ja | ja | Controller-/FFB-Profile | Beta |
| Assetto Corsa Competizione | - | - | - | Geplant |
| Le Mans Ultimate | - | - | - | Geplant |
| BeamNG.drive | - | - | - | Geplant |
| EA Sports WRC | - | - | - | Geplant |
| ETS2 / ATS | - | - | - | Geplant |
| Cyberpunk 2077 | - | - | - | Geplant |
| Minecraft | - | - | - | Geplant |
| Marvel Rivals | - | - | - | Geplant |
| GTA V | - | - | - | Geplant |

## Naechste Schritte

1. Assetto Corsa in der Praxis testen (Pfade, CSP-Erkennung, Profile).
2. ACC und Le Mans Ultimate - beide brauchen dieselben Bausteine wie AC.
3. Gemeinsames Simracing-Profil (ein FFB-Grundsetup fuer mehrere Spiele).
4. BeamNG und EA WRC.
5. Danach die Nicht-Simracing-Titel.

## Bekannte Grenzen

* Die Erkennung ist auf einem Linux-Rechner entwickelt und gegen Testdaten
  geprueft. Steam-, Epic- und Registry-Erkennung laufen erst auf einem
  echten Windows-PC durch den vollen Praxistest.
* Ob F1 seine Tastenbelegung als Datei ablegt oder im Cloud-Savegame, ist
  offen - die Diagnose im F1-Installer beantwortet das.
* Bei Assetto Corsa sind die Pfade aus der Dokumentation uebernommen und
  noch nicht auf einem echten System gegengeprueft.
