#!/bin/bash

# run.sh - Minimales Startup-Skript für Barcode Buddy Add-on

echo "=== Barcode Buddy USB Scanner Add-on startet ==="

# Standard-Werte
SCANNER_DEVICE="/dev/input/event0"
DEBUG="false"

# Home Assistant Add-on Konfiguration lesen
CONFIG_PATH="/data/options.json"

if [ -f "$CONFIG_PATH" ]; then
    echo "Konfigurationsdatei gefunden: $CONFIG_PATH"
    
    # Scanner-Gerät extrahieren (ohne jq, nur mit grep/sed)
    CONFIGURED_DEVICE=$(grep -o '"scanner_device"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    
    if [ -n "$CONFIGURED_DEVICE" ] && [ "$CONFIGURED_DEVICE" != "null" ]; then
        SCANNER_DEVICE="$CONFIGURED_DEVICE"
        echo "Verwende konfiguriertes Scanner-Gerät: $SCANNER_DEVICE"
    fi
    
    # Debug-Modus prüfen
    if grep -q '"debug"[[:space:]]*:[[:space:]]*true' "$CONFIG_PATH" 2>/dev/null; then
        DEBUG="true"
    fi
else
    echo "Keine Konfigurationsdatei gefunden, verwende Standard: $SCANNER_DEVICE"
fi

# Debug-Ausgaben
if [ "$DEBUG" = "true" ]; then
    echo "=== DEBUG-INFORMATIONEN ==="
    echo "Aktuelles Verzeichnis: $(pwd)"
    echo "Scanner-Gerät: $SCANNER_DEVICE"
    echo "Verfügbare /dev/input Geräte:"
    ls -la /dev/input/ 2>/dev/null || echo "Keine /dev/input Geräte"
    echo "Konfiguration:"
    cat "$CONFIG_PATH" 2>/dev/null || echo "Keine Konfigurationsdatei"
    echo "Umgebungsvariablen:"
    env | grep -i barcode || echo "Keine BARCODE-Variablen"
    echo "==========================="
fi

# Verfügbarkeit des Scanner-Geräts prüfen
if [ ! -e "$SCANNER_DEVICE" ]; then
    echo "WARNUNG: Scanner-Gerät $SCANNER_DEVICE nicht gefunden!"
    echo "Suche nach verfügbaren Alternativen..."
    
    # Erstes verfügbares event-Gerät finden
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            echo "Verwende alternatives Gerät: $device"
            SCANNER_DEVICE="$device"
            break
        fi
    done
    
    if [ ! -e "$SCANNER_DEVICE" ]; then
        echo "FEHLER: Kein Input-Gerät verfügbar!"
        echo "Verfügbare Geräte:"
        ls -la /dev/input/ 2>/dev/null || echo "Keine Geräte in /dev/input"
        exit 1
    fi
fi

# Umgebungsvariablen setzen
export ATTACH_BARCODESCANNER=true
export SCANNER_DEVICE="$SCANNER_DEVICE"

echo "Finale Konfiguration:"
echo "- Scanner-Gerät: $SCANNER_DEVICE"
echo "- ATTACH_BARCODESCANNER: $ATTACH_BARCODESCANNER"

# Finde das grabInput.sh Skript
GRAB_INPUT_SCRIPT=""
for path in \
    "/app/barcodebuddy/grabInput.sh" \
    "/opt/barcodebuddy/grabInput.sh" \
    "/usr/local/bin/grabInput.sh" \
    "$(find / -name "grabInput.sh" 2>/dev/null | head -1)"; do
    
    if [ -f "$path" ]; then
        GRAB_INPUT_SCRIPT="$path"
        echo "grabInput.sh gefunden: $GRAB_INPUT_SCRIPT"
        break
    fi
done

# Wrapper für grabInput.sh erstellen (falls das Skript gefunden wurde)
if [ -n "$GRAB_INPUT_SCRIPT" ]; then
    echo "Erstelle Wrapper für grabInput.sh..."
    
    # Original sichern
    cp "$GRAB_INPUT_SCRIPT" "${GRAB_INPUT_SCRIPT}.original" 2>/dev/null || true
    
    # Neuen Wrapper erstellen
    cat > "$GRAB_INPUT_SCRIPT" << EOF
#!/bin/bash
# Automatischer Wrapper für grabInput.sh
echo "Wrapper aufgerufen mit Argumenten: \$@"

# Verwende konfiguriertes Gerät
DEVICE="$SCANNER_DEVICE"

# Falls als Argument übergeben, verwende das
if [ "\$1" != "" ] && [ -e "\$1" ]; then
    DEVICE="\$1"
fi

if [ -e "\$DEVICE" ]; then
    echo "Starte Input-Grabber für: \$DEVICE"
    exec "${GRAB_INPUT_SCRIPT}.original" "\$DEVICE"
else
    echo "FEHLER: Gerät \$DEVICE nicht verfügbar!"
    echo "Verfügbare Geräte:"
    ls -la /dev/input/event* 2>/dev/null || echo "Keine event-Geräte"
    exit 1
fi
EOF
    
    chmod +x "$GRAB_INPUT_SCRIPT"
    echo "Wrapper erstellt und aktiviert"
else
    echo "WARNUNG: grabInput.sh nicht gefunden - Scanner-Funktionalität eventuell eingeschränkt"
fi

# Original-Entrypoint suchen und starten
echo "Suche Original-Entrypoint..."
for entrypoint in "/init" "/usr/local/bin/docker-entrypoint.sh" "/entrypoint.sh"; do
    if [ -f "$entrypoint" ]; then
        echo "Starte Original-System: $entrypoint"
        exec "$entrypoint"
    fi
done

echo "FEHLER: Kein Original-Entrypoint gefunden!"
echo "Verfügbare Dateien in /:"
ls -la / | head -20
exit 1