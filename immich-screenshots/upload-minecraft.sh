#!/bin/bash

# Minecraft Screenshot Auto-Upload Script for immich-go
# Überwacht dynamisch alle PrismLauncher Instanzen

# Konfiguration
PRISM_BASE="/home/sam/.local/share/PrismLauncher/instances"
CREDENTIALS_FILE="$HOME/.config/immich-go/credentials"
LOG_FILE="$HOME/.config/immich-go/upload-minecraft.log"
ERROR_LOG="$HOME/.config/immich-go/error-minecraft.log"
ALBUM_NAME="Minecraft"

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
    if immich-go upload from-folder \
        --server="$IMMICH_SERVER_URL" \
        --api-key="$IMMICH_API_KEY" \
        --into-album="$ALBUM_NAME" \
        --no-ui \
        "$file" >> "$LOG_FILE" 2>&1; then
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

# Prüfe ob Basis-Verzeichnis existiert
if [ ! -d "$PRISM_BASE" ]; then
    log_error "PrismLauncher Verzeichnis nicht gefunden: $PRISM_BASE"
    exit 1
fi

# Sammle alle Screenshot-Verzeichnisse
WATCH_DIRS=()
while IFS= read -r dir; do
    if [ -d "$dir" ]; then
        WATCH_DIRS+=("$dir")
    fi
done < <(find "$PRISM_BASE" -type d -path "*/minecraft/screenshots" 2>/dev/null)

# Prüfe ob mindestens ein Verzeichnis gefunden wurde
if [ ${#WATCH_DIRS[@]} -eq 0 ]; then
    log_error "Keine Minecraft Screenshot-Verzeichnisse gefunden in $PRISM_BASE"
    exit 1
fi

log "=== Minecraft Screenshot Auto-Upload gestartet ==="
log "Server: $IMMICH_SERVER_URL"
log "Album: $ALBUM_NAME"
log "Überwache ${#WATCH_DIRS[@]} Verzeichnis(se):"
for dir in "${WATCH_DIRS[@]}"; do
    log "  - $dir"
done

# Starte inotifywait in Schleife - überwacht alle Verzeichnisse gleichzeitig
inotifywait -m -e close_write,moved_to --format '%w%f' "${WATCH_DIRS[@]}" 2>/dev/null | while read file
do
    # Nur Bilddateien verarbeiten
    if [[ "$file" =~ \.(png|jpg|jpeg|gif|bmp|webp|PNG|JPG|JPEG|GIF|BMP|WEBP)$ ]]; then
        upload_file "$file"
    else
        log "Ignoriere Nicht-Bilddatei: $(basename "$file")"
    fi
done
