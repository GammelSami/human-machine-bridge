#!/bin/bash

# Screenshot Auto-Upload Script for immich-go
# Überwacht /home/sam/Bilder/Bildschirmfotos und lädt neue Dateien automatisch hoch

# Konfiguration
WATCH_DIR="/home/sam/Bilder/Bildschirmfotos"
CREDENTIALS_FILE="$HOME/.config/immich-go/credentials"
LOG_FILE="$HOME/.config/immich-go/upload.log"
ERROR_LOG="$HOME/.config/immich-go/error.log"

# Lade Credentials
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FEHLER: Credentials-Datei nicht gefunden: $CREDENTIALS_FILE" | tee -a "$ERROR_LOG"
    exit 1
fi

source "$CREDENTIALS_FILE"

# Prüfe ob notwendige Variablen gesetzt sind
if [ -z "$IMMICH_SERVER_URL" ] || [ -z "$IMMICH_API_KEY" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FEHLER: IMMICH_SERVER_URL oder IMMICH_API_KEY nicht gesetzt" | tee -a "$ERROR_LOG"
    exit 1
fi

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FEHLER: $1" | tee -a "$ERROR_LOG"
}

# Funktion zum Archivieren von Assets
archive_recent_assets() {
    log "Archiviere hochgeladene Assets..."

    # Hole alle nicht-archivierten Assets vom aktuellen Device
    local device_uuid=$(immich-go --help 2>&1 | grep "device-uuid" | grep -oP 'default "\K[^"]+' || echo "cachyOS")

    # Suche über Immich API nach nicht-archivierten Assets vom Device und archiviere sie
    local response=$(curl -s -X POST "$IMMICH_SERVER_URL/api/search/metadata" \
        -H "x-api-key: $IMMICH_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"deviceId\": \"$device_uuid\", \"isArchived\": false, \"take\": 100}")

    # Extrahiere Asset-IDs
    local asset_ids=$(echo "$response" | grep -oP '"id":\s*"\K[^"]+' | head -100)

    if [ -n "$asset_ids" ]; then
        # Erstelle JSON Array für API
        local ids_json="["
        local first=true
        for id in $asset_ids; do
            if [ "$first" = true ]; then
                ids_json="${ids_json}\"$id\""
                first=false
            else
                ids_json="${ids_json},\"$id\""
            fi
        done
        ids_json="${ids_json}]"

        # Archiviere Assets
        curl -s -X PUT "$IMMICH_SERVER_URL/api/assets" \
            -H "x-api-key: $IMMICH_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"ids\": $ids_json, \"isArchived\": true}" > /dev/null

        local count=$(echo "$asset_ids" | wc -l)
        log "✓ $count Asset(s) archiviert"
    fi
}

# Upload-Funktion
upload_file() {
    local file="$1"

    # Warte kurz, falls die Datei noch geschrieben wird
    sleep 2

    # Prüfe ob Datei existiert und lesbar ist
    if [ ! -f "$file" ]; then
        log_error "Datei nicht gefunden: $file"
        return 1
    fi

    log "Uploading: $(basename "$file")"

    # Upload mit immich-go
    local upload_cmd="immich-go upload from-folder --server=\"$IMMICH_SERVER_URL\" --api-key=\"$IMMICH_API_KEY\" --no-ui"

    # Optional: Album hinzufügen
    if [ -n "$IMMICH_ALBUM" ]; then
        upload_cmd="$upload_cmd --into-album=\"$IMMICH_ALBUM\""
    fi

    upload_cmd="$upload_cmd \"$file\""

    # Führe Upload aus
    if eval $upload_cmd >> "$LOG_FILE" 2>&1; then
        log "✓ Erfolgreich hochgeladen: $(basename "$file")"
        # Archiviere das hochgeladene Asset
        archive_recent_assets
    else
        log_error "Upload fehlgeschlagen: $(basename "$file")"
        return 1
    fi
}

# Prüfe ob inotifywait verfügbar ist
if ! command -v inotifywait &> /dev/null; then
    log_error "inotifywait nicht gefunden. Bitte installiere inotify-tools: sudo pacman -S inotify-tools"
    exit 1
fi

# Prüfe ob Verzeichnis existiert
if [ ! -d "$WATCH_DIR" ]; then
    log_error "Überwachungsverzeichnis nicht gefunden: $WATCH_DIR"
    exit 1
fi

log "=== Screenshot Auto-Upload gestartet ==="
log "Überwache Verzeichnis: $WATCH_DIR"
log "Server: $IMMICH_SERVER_URL"
log "Album: ${IMMICH_ALBUM:-Nicht gesetzt}"

# Starte inotifywait in Schleife
inotifywait -m -e close_write,moved_to --format '%w%f' "$WATCH_DIR" | while read file
do
    # Nur Bilddateien verarbeiten
    if [[ "$file" =~ \.(png|jpg|jpeg|gif|bmp|webp|PNG|JPG|JPEG|GIF|BMP|WEBP)$ ]]; then
        upload_file "$file"
    else
        log "Ignoriere Nicht-Bilddatei: $(basename "$file")"
    fi
done
