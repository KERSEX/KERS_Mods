# KERS F1 Mods Installer

Alles rund um die F1-Spiele (F1 2015 bis F1 26). Die Datei
`KERS_F1_Mods_Installer.cmd` laeuft eigenstaendig - Doppelklick genuegt,
der Rest des Repositories wird dafuer nicht gebraucht.

```
   MOZA Wheel-Fix
   1) installieren
   2) deinstallieren (Originalzustand)
   3) nur testen (nichts schreiben)

   Einstellungen (Dokumente\My Games)
   4) KERS-Grafik-Preset anwenden (FSR/DLSS je GPU, UDP an)
   5) eigene Einstellungen sichern
   6) gesichertes Preset wiederherstellen
   7) Diagnose: was legt das Spiel an?
```

## Bedienung

1. `KERS_F1_Mods_Installer.cmd` doppelklicken (am besten als Administrator -
   der Installer bietet den Neustart mit Adminrechten aber auch selbst an).
2. Menuepunkt waehlen.
3. Wheelbase bestaetigen, Spiele auswaehlen (Enter = alle), Lenkrad
   auswaehlen - fertig.
4. Im Spiel unter *Einstellungen -> Steuerung* das Geraet auswaehlen und die
   Belegung pruefen.

## MOZA Wheel-Fix

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

## KERS-Grafik-Preset anwenden

Menuepunkt `4` schreibt das mitgelieferte Preset
(`presets/f1_25_kers_settings.xml`, aus F1 25/26) in die
`hardware_settings_config.xml` des gewaehlten Spiels.

**Vom eigenen Rechner bleibt stehen** (wird nie ueberschrieben):

| bleibt | warum |
|---|---|
| `<cpu>` | Prozessor und Kernzuordnung |
| `<graphics_card deviceId>` | GPU-Kennung |
| `<resolution>` mit allem drin | Aufloesung, Monitor, Bildwiederholrate, HDR, V-Sync, FPS-Limit |
| `texture_streaming sizeInMiB` | haengt am VRAM |
| `audio num_job_worker_threads` | haengt an der CPU |
| `<led_display>` | Fanatec-/SLI-Pro-/Wooting-Displays |
| `<replay_directory>` | eigener Replay-Pfad |
| `udp format` | die UDP-Version gehoert zum Spieljahr |

**Upscaling richtet sich nach der Grafikkarte** (ueber `Win32_VideoController`
ausgelesen):

* **RTX** &rarr; DLSS bleibt an, so wie im Preset
* **keine RTX** (Radeon, Arc, GTX ...) &rarr; DLSS aus, **FSR an, Stufe
  "ausgewogen"**. Auf Nicht-NVIDIA-Karten werden ausserdem Reflex und SER
  abgeschaltet - die laufen dort ohnehin nicht.
* Kennt ein aelteres Spiel gar kein FSR, bleibt die Kantenglaettung in Ruhe
  und TAA bleibt an, statt ohne alles dazustehen.

**Immer gesetzt:** Frame Generation aus (`frame_gen mode="0"`,
`multi_frame_gen value="0"`), UDP-Telemetrie `enabled="true"` und
`onlineNames="on"`.

Uebertragen werden nur Werte, die es im Zielspiel wirklich gibt - alles was
das jeweilige Spieljahr nicht kennt, wird uebersprungen statt neu angelegt.
Am Ende steht, wie viele Werte gesetzt, behalten und uebersprungen wurden.
Vor dem Schreiben legt der Installer automatisch das Preset
`vor_kers_preset` an, Menuepunkt `6` spielt es zurueck.

## Einstellungen sichern und wiederherstellen

Menuepunkt `5` sichert, was ein Spiel unter
`Dokumente\My Games\F1 <Jahr>` ablegt - Grafik- und Spieleinstellungen,
Force-Feedback, und Tastenbelegungen, soweit sie dort als Datei liegen.
Gesichert werden die Ordner `hardwaresettings`, `actionmaps`,
`graphicsconfig` und `settings`; **Savegames bleiben unberuehrt**.

* Preset-Ablage: `%LOCALAPPDATA%\KERS_Mods\presets\<Spiel>\<zeitstempel>_<name>`
* Menuepunkt `6` spielt ein Preset zurueck und legt vorher automatisch
  eine Sicherung des aktuellen Stands als `vor_wiederherstellung` an.

Nuetzlich nach einem Spiel-Patch, der die Grafikeinstellungen
zuruecksetzt, oder vor dem Ausprobieren neuer Settings.

## Diagnose

Menuepunkt `7` listet, welche Dateien und Ordner das jeweilige Spiel unter
`Dokumente\My Games` tatsaechlich angelegt hat, und schreibt die Liste
zusaetzlich als `KERS_F1_Diagnose.txt` auf den Desktop. Damit laesst sich
klaeren, welche Einstellungen ein Spiel ueberhaupt als Datei ablegt und
welche im (Cloud-)Savegame stecken.

## Aeltere Einzel-Skripte

`KERS_Mod_f1-2021_moza_r3.cmd` und `KERS_Mod_f1-2021_moza_r5.cmd`
installieren die native MOZA-Map fest fuer F1 2021. Der Installer
kann das ebenfalls (Lenkrad-Auswahl `0` = *MOZA nativ*), zusaetzlich aber
jedes andere F1-Spiel und jedes Modell.
