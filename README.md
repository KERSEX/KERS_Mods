# KERS_Mods

Mods for some Games

## KERS F1 Mods Installer (F1 2015 - F1 26)

`KERS_F1_Mods_Installer.cmd` - eine Datei, Doppelklick. Enthaelt den
MOZA Wheel-Fix und die Einstellungs-Werkzeuge.

```
   MOZA Wheel-Fix
   1) installieren
   2) deinstallieren (Originalzustand)
   3) nur testen (nichts schreiben)

   Einstellungen (Dokumente\My Games)
   4) Grafik-/Spiel-Einstellungen sichern
   5) gesichertes Preset wiederherstellen
   6) Diagnose: was legt das Spiel an?
```

### MOZA Wheel-Fix

* **erkennt die angeschlossene MOZA Wheelbase automatisch** (USB VID `346E`)
  und liest die Product-ID direkt am Geraet aus. Wird nichts gefunden,
  fragt er nach (R3, R5, R9, R12, R16/R21, R8 oder PID manuell).
* **findet alle installierten F1-Spiele** (F1 2015 bis F1 26) ueber
  Steam-Bibliotheken, Epic-Manifeste, die EA/Origin-Ordner, einen
  Laufwerks-Scan und die Registry. Pfade lassen sich zusaetzlich manuell
  ergaenzen.
* **laesst dich waehlen, als welches Lenkrad die Base laufen soll.**
  Angeboten wird alles, was das jeweilige Spiel selbst kennt
  (z.B. Fanatec CSL Elite / Podium, Logitech G29 / G923, Thrustmaster
  T300 / TS-XW ...) - plus die mitgelieferte native KERS-Map.
* **traegt die Base fest als `KERS_<MODELL>_F1_MOD` ein**, also z.B.
  **`KERS_R5_F1_MOD`** - so steht sie in der Geraeteliste des Spiels.
* **installiert die Actionmap in jedes gewaehlte Spiel** als
  `actionmaps\KERS_R5_F1_MOD.xml`, inklusive Backup und Log.

Die F1-Spiele erkennen nur Lenkraeder, die in `actionmaps\*.xml` mit ihrer
DirectInput-GUID hinterlegt sind. Die GUID hat das Format
`{PPPPVVVV-0000-0000-0000-504944564944}` - also z.B. `{0005346E-...}`
fuer eine MOZA R3 (PID `0005`, VID `346E`).

Der Installer kopiert das Profil des gewaehlten Lenkrads, setzt die GUID
auf die der MOZA und vergibt den Profilnamen `KERS_<MODELL>_F1_MOD`.
Dieser Name steht sowohl im `name`/`actionMapName` als auch im
`display`/`deviceDisplayKey`, taucht also genau so in der Geraeteliste des
Spiels auf. Belegung und Symbole kommen weiter vom emulierten Lenkrad. Die
Originaldateien des Spiels werden nicht angefasst - es kommt nur eine neue
Datei dazu.

* installiert wird: `<Spiel>\actionmaps\KERS_R5_F1_MOD.xml`
* Backup vorhandener MOZA-Dateien (auch aelterer `moza_*.xml`):
  `...xml.kersbak_<zeitstempel>`
* Log: `%LOCALAPPDATA%\KERS_Mods\moza_f1_installer.log`

Deinstallation (Menuepunkt `2`) erkennt MOZA-Actionmaps an ihrer GUID -
unabhaengig vom Dateinamen - und entfernt sie samt Backups wieder. Das
Spiel ist damit exakt im Auslieferungszustand.

### Einstellungen sichern und wiederherstellen

Menuepunkt `4` sichert, was ein Spiel unter
`Dokumente\My Games\F1 <Jahr>` ablegt - Grafik- und Spieleinstellungen,
Force-Feedback, und Tastenbelegungen, soweit sie dort als Datei liegen.
Gesichert werden die Ordner `hardwaresettings`, `actionmaps`,
`graphicsconfig` und `settings`; **Savegames bleiben unberuehrt**.

* Preset-Ablage: `%LOCALAPPDATA%\KERS_Mods\presets\<Spiel>\<zeitstempel>_<name>`
* Menuepunkt `5` spielt ein Preset zurueck und legt vorher automatisch
  eine Sicherung des aktuellen Stands als `vor_wiederherstellung` an.

Nuetzlich nach einem Spiel-Patch, der die Grafikeinstellungen
zuruecksetzt, oder vor dem Ausprobieren neuer Settings.

### Diagnose

Menuepunkt `6` listet, welche Dateien und Ordner das jeweilige Spiel unter
`Dokumente\My Games` tatsaechlich angelegt hat, und schreibt die Liste
zusaetzlich als `KERS_F1_Diagnose.txt` auf den Desktop. Damit laesst sich
klaeren, welche Einstellungen ein Spiel ueberhaupt als Datei ablegt und
welche im (Cloud-)Savegame stecken.

### Aeltere Einzel-Skripte

`KERS_Mod_f1-2021_moza_r3.cmd` und `KERS_Mod_f1-2021_moza_r5.cmd`
installieren die native MOZA-Map fest fuer F1 2021. Der Installer
kann das ebenfalls (Lenkrad-Auswahl `0` = *MOZA nativ*), zusaetzlich aber
jedes andere F1-Spiel und jedes Modell.
