#!/bin/bash

# patch-scanner.sh v1.1.5 - Exec Fix für MINJCODE Scanner

echo "=== Barcode Buddy Scanner-Patch v1.1.5 ==="

# Debug-Modus aus Konfiguration
DEBUG_MODE="false"
CONFIG_PATH="/data/options.json"
if [ -f "$CONFIG_PATH" ]; then
    if grep -q '"debug"[[:space:]]*:[[:space:]]*true' "$CONFIG_PATH" 2>/dev/null; then
        DEBUG_MODE="true"
        echo "Debug-Modus aktiviert"
    fi
fi

# Scanner-Gerät aus Konfiguration lesen
SCANNER_DEVICE="/dev/input/event2"
if [ -f "$CONFIG_PATH" ]; then
    CONFIGURED_DEVICE=$(grep -o '"scanner_device"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    
    if [ -n "$CONFIGURED_DEVICE" ] && [ "$CONFIGURED_DEVICE" != "null" ]; then
        SCANNER_DEVICE="$CONFIGURED_DEVICE"
    fi
fi

echo "Scanner-Gerät: $SCANNER_DEVICE"

# grabInput.sh analysieren und reparieren
GRAB_SCRIPT="/app/bbuddy/example/grabInput.sh"

if [ -f "$GRAB_SCRIPT" ]; then
    echo "Analysiere grabInput.sh..."
    
    # Backup erstellen (nur einmal)
    if [ ! -f "${GRAB_SCRIPT}.original" ]; then
        cp "$GRAB_SCRIPT" "${GRAB_SCRIPT}.original"
        echo "Original-Skript gesichert"
    fi
    
    # Original-Skript analysieren
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== ORIGINAL-SKRIPT ANALYSE ==="
        echo "Dateigröße: $(wc -c < "${GRAB_SCRIPT}.original") bytes"
        echo "Erste Zeilen:"
        head -3 "${GRAB_SCRIPT}.original" 2>/dev/null || echo "Kann nicht gelesen werden"
        echo "Berechtigungen:"
        ls -la "${GRAB_SCRIPT}.original"
        echo "Dateityp:"
        file "${GRAB_SCRIPT}.original" 2>/dev/null || echo "file-Befehl nicht verfügbar"
        echo "================================"
    fi
    
    # Berechtigungen reparieren
    chmod +x "${GRAB_SCRIPT}.original" 2>/dev/null
    
    # Korrigierten Wrapper erstellen (Original-Skript funktioniert!)
    cat > "$GRAB_SCRIPT" << 'EOF'
#!/bin/bash
# Korrigierter Scanner-Wrapper v1.1.5 - Exec Fix

echo "Scanner-Wrapper v1.1.5 gestartet (Exec Fix)"

# Hardware-Check
if [ ! -d "/dev/input/" ]; then
    echo "SIMULATION: Keine Hardware-Scanner verfügbar"
    
    while true; do
        sleep 60
        echo "$(date +%H:%M): Scanner-Simulation aktiv"
    done
    exit 0
fi

# Scanner-Gerät bestimmen
DEVICE="/dev/input/event2"  # Standard für MINJCODE

# Argument-Override
if [ "$1" != "" ] && [ -e "$1" ]; then
    DEVICE="$1"
    echo "Verwende Argument-Gerät: $DEVICE"
fi

# Fallback-Suche
if [ ! -e "$DEVICE" ]; then
    echo "Gerät $DEVICE nicht verfügbar, suche Alternativen..."
    
    for candidate in /dev/input/event*; do
        if [ -e "$candidate" ]; then
            DEVICE="$candidate"
            echo "Auto-Erkennung: $DEVICE"
            break
        fi
    done
fi

# Gerät validieren
if [ ! -e "$DEVICE" ] || [ "$DEVICE" = "/dev/null" ]; then
    echo "⚠️  Hardware-Scanner nicht verfügbar"
    echo "💻 Web-Interface verfügbar auf Port 8083"
    
    while true; do
        sleep 60
        echo "$(date +%H:%M): Warte auf Hardware-Scanner..."
    done
    exit 0
fi

echo "🔍 MINJCODE Scanner bereit: $DEVICE"

# Original-Skript (absoluter Pfad für sicheren Exec)
ORIGINAL_SCRIPT="/app/bbuddy/example/grabInput.sh.original"

if [ -f "$ORIGINAL_SCRIPT" ]; then
    chmod +x "$ORIGINAL_SCRIPT"
    echo "✅ Starte Original-Scanner für: $DEVICE"
    echo "[ScannerConnection] Erwartet Scanner-Input..."
    
    # KORRIGIERTER EXEC-AUFRUF - Absolute Pfade verwenden
    exec "$ORIGINAL_SCRIPT" "$DEVICE"
else
    echo "❌ Original-Skript nicht gefunden: $ORIGINAL_SCRIPT"
    
    # Fallback
    while true; do
        if [ -e "$DEVICE" ]; then
            echo "$(date +%H:%M:%S): Fallback-Scanner aktiv auf $DEVICE"
        fi
        sleep 60
    done
fi
EOF
    
    chmod +x "$GRAB_SCRIPT"
    echo "✅ Korrigierter Scanner-Wrapper v1.1.5 installiert"
    
else
    echo "⚠️  grabInput.sh nicht gefunden bei $GRAB_SCRIPT"
fi

# Umgebungsvariablen setzen
export ATTACH_BARCODESCANNER=true
export SCANNER_DEVICE="$SCANNER_DEVICE"

echo ""
echo "🚀 Starte Barcode Buddy System v1.1.5..."

# Original-Supervisor starten
if [ -f "/app/supervisor" ]; then
    echo "Starte /app/supervisor..."
    exec /app/supervisor
else
    echo "❌ FEHLER: /app/supervisor nicht gefunden!"
    exit 1
fi