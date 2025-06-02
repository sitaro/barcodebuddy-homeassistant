#!/usr/bin/with-contenv bashio

# run.sh - Home Assistant Add-on Startup-Skript für Barcode Buddy

bashio::log.info "Starte Barcode Buddy USB Scanner Add-on..."

# Lese die Konfiguration aus Home Assistant
CONFIG_PATH="/data/options.json"

# Prüfe ob Konfigurationsdatei existiert
if [ ! -f "$CONFIG_PATH" ]; then
    bashio::log.warning "Keine Konfigurationsdatei gefunden, verwende Standard-Werte"
    SCANNER_DEVICE="/dev/input/event0"
else
    # Lese scanner_device aus der Konfiguration
    SCANNER_DEVICE=$(bashio::config 'scanner_device')
    
    # Fallback auf Standard-Wert falls nicht konfiguriert
    if [ -z "$SCANNER_DEVICE" ] || [ "$SCANNER_DEVICE" = "null" ]; then
        SCANNER_DEVICE="/dev/input/event0"
        bashio::log.info "Kein Scanner-Gerät konfiguriert, verwende Standard: $SCANNER_DEVICE"
    else
        bashio::log.info "Verwende konfiguriertes Scanner-Gerät: $SCANNER_DEVICE"
    fi
fi

# Prüfe ob das Scanner-Gerät existiert
if [ ! -e "$SCANNER_DEVICE" ]; then
    bashio::log.warning "Scanner-Gerät $SCANNER_DEVICE nicht gefunden!"
    bashio::log.info "Verfügbare Input-Geräte:"
    ls -la /dev/input/event* 2>/dev/null || bashio::log.warning "Keine Input-Geräte gefunden"
    
    # Versuche automatische Erkennung
    bashio::log.info "Versuche automatische Geräteerkennung..."
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            bashio::log.info "Gefunden: $device"
            SCANNER_DEVICE="$device"
            break
        fi
    done
fi

# Weitere Konfigurationsoptionen lesen
DEBUG=$(bashio::config 'debug')
REQUIRE_API_KEY=$(bashio::config 'require_api_key')
DISABLE_AUTH=$(bashio::config 'disable_auth')

# Debug-Informationen ausgeben
if [ "$DEBUG" = "true" ]; then
    bashio::log.info "=== DEBUG-INFORMATIONEN ==="
    bashio::log.info "Scanner-Gerät: $SCANNER_DEVICE"
    bashio::log.info "Debug aktiviert: $DEBUG"
    bashio::log.info "API-Key erforderlich: $REQUIRE_API_KEY"
    bashio::log.info "Authentifizierung deaktiviert: $DISABLE_AUTH"
    bashio::log.info "Umgebungsvariablen:"
    env | grep -E "(ATTACH_|BARCODE|SCANNER)" || true
    bashio::log.info "==========================="
fi

# Umgebungsvariablen für Barcode Buddy setzen
export ATTACH_BARCODESCANNER=true
export SCANNER_DEVICE="$SCANNER_DEVICE"

# Original-Entrypoint finden und ausführen
ORIGINAL_ENTRYPOINT="/init"

if [ -f "$ORIGINAL_ENTRYPOINT" ]; then
    bashio::log.info "Starte Barcode Buddy mit Scanner-Gerät: $SCANNER_DEVICE"
    
    # Prüfe ob grabInput.sh existiert und modifiziere es falls nötig
    if [ -f "/app/barcodebuddy/grabInput.sh" ]; then
        # Erstelle eine Wrapper-Funktion die das Gerät automatisch übergibt
        cat > /usr/local/bin/grabInput-wrapper.sh << EOF
#!/bin/bash
# Wrapper für grabInput.sh mit automatischer Geräteerkennung
if [ -n "$SCANNER_DEVICE" ] && [ -e "$SCANNER_DEVICE" ]; then
    exec /app/barcodebuddy/grabInput.sh "$SCANNER_DEVICE" "\$@"
else
    echo "Fehler: Scanner-Gerät $SCANNER_DEVICE nicht verfügbar"
    exit 1
fi
EOF
        chmod +x /usr/local/bin/grabInput-wrapper.sh
        
        # Ersetze grabInput.sh durch unseren Wrapper
        mv /app/barcodebuddy/grabInput.sh /app/barcodebuddy/grabInput-original.sh
        ln -sf /usr/local/bin/grabInput-wrapper.sh /app/barcodebuddy/grabInput.sh
    fi
    
    # Starte das Original-System
    exec "$ORIGINAL_ENTRYPOINT"
else
    bashio::log.error "Original-Entrypoint $ORIGINAL_ENTRYPOINT nicht gefunden!"
    exit 1
fi