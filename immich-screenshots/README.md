# Immich Screenshot Auto-Upload

Automatischer Upload von Screenshots nach Immich mit inotifywait.

## Services

1. **immich-screenshots.service** - System-Screenshots (`/home/sam/Bilder/Bildschirmfotos`) → Album "PC Screenshots"
2. **immich-minecraft.service** - Minecraft Screenshots (alle PrismLauncher Instanzen) → Album "Minecraft"
3. **immich-steam.service** - Steam Screenshots (dynamisch alle Spiele) → Album "Steam"

## Dateien

### Scripts
- `upload-screenshots.sh` - PC Screenshots Upload-Script
- `upload-minecraft.sh` - Minecraft Screenshots Upload-Script
- `upload-steam.sh` - Steam Screenshots Upload-Script
- `credentials` - Gemeinsame Zugangsdaten für alle Services

### Log-Dateien
- `upload.log` - PC Screenshots Log
- `upload-minecraft.log` - Minecraft Log
- `upload-steam.log` - Steam Log
- `error.log` - PC Screenshots Fehler
- `error-minecraft.log` - Minecraft Fehler
- `error-steam.log` - Steam Fehler
- `service*.log` - Systemd Service Logs

## Einrichtung

### 1. inotify-tools installieren

```bash
sudo pacman -S inotify-tools
```

### 2. Credentials konfigurieren

Bearbeite `~/.config/immich-go/credentials` und trage ein:

```bash
IMMICH_SERVER_URL="https://dein-immich-server.com"
IMMICH_API_KEY="dein-api-key"
IMMICH_ALBUM="Screenshots"  # Optional
```

API-Key erhältst du in Immich unter: **Benutzereinstellungen → API-Keys → Neuer API-Key**

### 3. Systemd Services aktivieren

```bash
# Services neu laden
systemctl --user daemon-reload

# Alle Services aktivieren (starten automatisch bei Login)
systemctl --user enable immich-screenshots.service
systemctl --user enable immich-minecraft.service
systemctl --user enable immich-steam.service

# Alle Services jetzt starten
systemctl --user start immich-screenshots.service
systemctl --user start immich-minecraft.service
systemctl --user start immich-steam.service
```

## Verwendung

### Service-Status prüfen

```bash
# Alle Services
systemctl --user status immich-*.service

# Einzelne Services
systemctl --user status immich-screenshots.service
systemctl --user status immich-minecraft.service
systemctl --user status immich-steam.service
```

### Logs anzeigen

```bash
# PC Screenshots
tail -f ~/.config/immich-go/upload.log
tail -f ~/.config/immich-go/error.log

# Minecraft
tail -f ~/.config/immich-go/upload-minecraft.log
tail -f ~/.config/immich-go/error-minecraft.log

# Steam
tail -f ~/.config/immich-go/upload-steam.log
tail -f ~/.config/immich-go/error-steam.log

# Alle gleichzeitig
tail -f ~/.config/immich-go/upload*.log

# Service-Logs
journalctl --user -u immich-screenshots.service -f
journalctl --user -u immich-minecraft.service -f
journalctl --user -u immich-steam.service -f
```

### Services neu starten

```bash
# Alle
systemctl --user restart immich-*.service

# Einzeln
systemctl --user restart immich-screenshots.service
systemctl --user restart immich-minecraft.service
systemctl --user restart immich-steam.service
```

### Services stoppen

```bash
systemctl --user stop immich-*.service
```

### Services deaktivieren (Autostart)

```bash
systemctl --user disable immich-screenshots.service
systemctl --user disable immich-minecraft.service
systemctl --user disable immich-steam.service
```

## Manueller Test

Du kannst die Scripts auch manuell testen:

```bash
# PC Screenshots
~/.config/immich-go/upload-screenshots.sh

# Minecraft
~/.config/immich-go/upload-minecraft.sh

# Steam
~/.config/immich-go/upload-steam.sh
```

## Funktionsweise

### PC Screenshots Service
1. Überwacht `/home/sam/Bilder/Bildschirmfotos`
2. Lädt neue Bilder ins Album "PC Screenshots"

### Minecraft Service
1. Findet dynamisch alle PrismLauncher Instanzen
2. Überwacht alle `/home/sam/.local/share/PrismLauncher/instances/*/minecraft/screenshots` Verzeichnisse
3. Lädt neue Bilder ins Album "Minecraft"

### Steam Service
1. Findet dynamisch alle Steam Screenshot-Verzeichnisse
2. Überwacht `/home/sam/.local/share/Steam/userdata/*/760/remote/*/screenshots`
3. Lädt neue Bilder ins Album "Steam"
4. Wartet auf neue Verzeichnisse, falls noch keine existieren

**Alle Services:**
- Nutzen **inotifywait** zur Verzeichnisüberwachung
- Warten 2 Sekunden nach Dateierstellung (falls noch geschrieben wird)
- Uploaden mit `immich-go upload from-folder`
- Loggen alle Aktionen

## Unterstützte Formate

- PNG
- JPG/JPEG
- GIF
- BMP
- WEBP

## Troubleshooting

### Service startet nicht

```bash
# Prüfe ob inotify-tools installiert ist
which inotifywait

# Prüfe Credentials
cat ~/.config/immich-go/credentials

# Prüfe ob Script ausführbar ist
ls -l ~/.config/immich-go/upload-screenshots.sh
```

### Uploads funktionieren nicht

```bash
# Teste manuellen Upload
immich-go upload -server="DEINE_URL" -key="DEIN_KEY" "/home/sam/Bilder/Bildschirmfotos/test.png"

# Prüfe Error-Log
cat ~/.config/immich-go/error.log
```

### Logs rotieren

Die Log-Dateien wachsen mit der Zeit. Du kannst sie regelmäßig leeren:

```bash
# Logs leeren
> ~/.config/immich-go/upload.log
> ~/.config/immich-go/error.log
```

Oder automatisch mit logrotate konfigurieren.
