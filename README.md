# KERS_Mods

Mods for some Games

## MOZA Wheelbase AutoInstaller fuer F1 2015 - F1 23

`KERS_Mod_F1_MOZA_AutoInstaller.cmd`

Eine einzige Datei - Doppelklick genuegt. Der Installer

* **erkennt die angeschlossene MOZA Wheelbase automatisch** (USB VID `346E`)
  und liest die Product-ID direkt am Geraet aus. Wird nichts gefunden,
  fragt er nach (R3, R5, R9, R12, R16/R21, R8 oder PID manuell).
* **findet alle installierten F1-Spiele** (F1 2015 bis F1 23) ueber
  Steam-Bibliotheken, Epic-Manifeste, die EA/Origin-Ordner, einen
  Laufwerks-Scan und die Registry. Pfade lassen sich zusaetzlich manuell
  ergaenzen.
* **laesst dich waehlen, als welches Lenkrad die Base laufen soll.**
  Angeboten wird alles, was das jeweilige Spiel selbst kennt
  (z.B. Fanatec CSL Elite / Podium, Logitech G29 / G923, Thrustmaster
  T300 / TS-XW ...) - plus die mitgelieferte native KERS-Map.
* **installiert die Actionmap in jedes gewaehlte Spiel** als
  `actionmaps\moza_<modell>.xml`, inklusive Backup und Log.

### Bedienung

1. `KERS_Mod_F1_MOZA_AutoInstaller.cmd` doppelklicken
   (am besten gleich *Als Administrator ausfuehren* - der Installer bietet
   den Neustart mit Adminrechten aber auch selbst an; ohne sie kann in
   `Program Files` nicht geschrieben werden).
2. Im Menue waehlen:
   * `1` Mod installieren
   * `2` Mod deinstallieren (Originalzustand wiederherstellen)
   * `3` nur testen - zeigt an, was passieren wuerde, schreibt aber nichts
3. Wheelbase bestaetigen, Spiele auswaehlen (Enter = alle), Lenkrad
   auswaehlen - fertig.
4. Im Spiel unter *Einstellungen -> Steuerung* das Geraet auswaehlen und
   die Belegung pruefen.

### Was genau passiert

Die F1-Spiele erkennen nur Lenkraeder, die in `actionmaps\*.xml` mit ihrer
DirectInput-GUID hinterlegt sind. Die GUID hat das Format
`{PPPPVVVV-0000-0000-0000-504944564944}` - also z.B. `{0005346E-...}`
fuer eine MOZA R3 (PID `0005`, VID `346E`).

Der Installer kopiert das Profil des gewaehlten Lenkrads, setzt die GUID
auf die der MOZA und vergibt einen eigenen Profilnamen
(`moza_r3`, `moza_r5`, ...). Der Anzeige-Key des Originals bleibt erhalten,
damit Name, Symbole und Tastenbelegung im Spiel stimmen. Die Originaldatei
des Spiels wird dabei nicht angefasst - es kommt nur eine neue Datei dazu.

* installiert wird: `<Spiel>\actionmaps\moza_<modell>.xml`
* Backup einer bereits vorhandenen MOZA-Datei: `...xml.kersbak_<zeitstempel>`
* Log: `%LOCALAPPDATA%\KERS_Mods\moza_f1_installer.log`
* Uebersicht der Installationen: `%LOCALAPPDATA%\KERS_Mods\moza_f1_install.json`

Deinstallation (Menuepunkt `2`) entfernt die `moza_*.xml` und die Backups
wieder - das Spiel ist damit exakt im Auslieferungszustand.

### Aeltere Einzel-Skripte

`KERS_Mod_f1-2021_moza_r3.cmd` und `KERS_Mod_f1-2021_moza_r5.cmd`
installieren die native MOZA-Map fest fuer F1 2021. Der AutoInstaller
kann das ebenfalls (Lenkrad-Auswahl `0` = *MOZA nativ*), zusaetzlich aber
jedes andere F1-Spiel und jedes Modell.
