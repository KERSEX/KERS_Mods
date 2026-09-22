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
| Assetto Corsa | ja | ja | Controller-/Grafik-Profile, Content Manager einrichten | Beta |
| Assetto Corsa Competizione | ja | ja | Wheel-/FFB- und Grafik-Profile | Beta |
| Le Mans Ultimate | ja | ja | Wheel-/FFB- und Grafik-Profile | Beta |
| BeamNG.drive | ja | ja | Controller-/Grafik-Profile, Mods an/aus | Beta |
| EA Sports WRC | ja | ja | Wheel-/FFB- und Grafik-Profile | Beta |
| Euro Truck Simulator 2 | ja | ja | Steuerungs-/Grafik-Profile, Mods an/aus | Beta |
| American Truck Simulator | ja | ja | Steuerungs-/Grafik-Profile, Mods an/aus | Beta |
| Cyberpunk 2077 | ja | ja | Einstellungs-Profile, .archive-Mods an/aus | Beta |
| Minecraft (Java) | ja | ja | Einstellungs-Profile, JAR-Mods an/aus | Beta |
| Marvel Rivals | ja | ja | Grafik-/Steuerungs-Profile (nur Config) | Beta |
| Grand Theft Auto V | ja | ja | Grafik-Profile, ASI-Mods an/aus | Beta |

## Naechste Schritte

Alle Spiele aus dem Plan sind gebaut. Offen ist:

1. Der Praxistest auf einem echten Windows-PC - Erkennung und Dateinamen.
   Dafuer reicht ein Durchlauf von *Diagnose* je Spiel.
2. GUI. Bewusst noch nicht gebaut: die CLI soll erst in der Praxis stabil
   sein, und eine Oberflaeche liesse sich hier nicht testen.
3. Gemeinsames Simracing-Profil ueber mehrere Spiele hinweg. Geprueft und
   vorerst zurueckgestellt: jedes Spiel speichert FFB anders (INI, JSON,
   SII, eigene Skalen). Ein echtes Uebersetzen braucht je Spiel eine
   Umrechnungstabelle mit Messwerten - alles andere waere geraten. Was
   heute geht: *Alle erkannten Spiele sichern* im Hauptmenue.

## Bekannte Grenzen

* Die Erkennung ist auf einem Linux-Rechner entwickelt und gegen Testdaten
  geprueft. Steam-, Epic- und Registry-Erkennung laufen erst auf einem
  echten Windows-PC durch den vollen Praxistest.
* Ob F1 seine Tastenbelegung als Datei ablegt oder im Cloud-Savegame, ist
  offen - die Diagnose im F1-Installer beantwortet das.
* Marvel Rivals: es wird ausschliesslich der Konfigurationsordner
  angefasst, nie der Spielordner.
* GTA V: Mods gehoeren in den Storymodus. Das Tool warnt davor, mit
  aktiven Mods online zu gehen, und ist genau dafuer da, vorher alles
  abzuschalten.
* Content Manager wird nicht mitgeliefert und nicht automatisch
  heruntergeladen. Das Tool zeigt die offizielle Adresse, oeffnet auf
  Wunsch den Browser und richtet eine bereits heruntergeladene Datei ein.
* Bei allen Spielen ausser F1 sind Ordner- und Dateinamen
  aus der Dokumentation uebernommen und noch nicht auf einem echten System
  gegengeprueft. Die Plugins sichern deshalb nur, was sie wirklich finden,
  und die Diagnose zeigt den Ist-Zustand - damit faellt sofort auf, wenn
  eine Datei anders heisst.
