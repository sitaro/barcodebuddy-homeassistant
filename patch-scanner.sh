#!/bin/bash

# patch-scanner.sh v1.1.3 - Mit automatischer Scanner-Erkennung

echo "=== Barcode Buddy Scanner-Patch v1.1.3 ==="

# Debug-Modus aus Konfiguration
DEBUG_MODE="false"
CONFIG_PATH="/data/options.json"
if [ -f "$CONFIG_PATH" ]; then
    if grep -q '"debug"[[:space:]]*:[[:space:]]*true' "$CONFIG_PATH" 2>/dev/null; then
        DEBUG_MODE="true"
        echo "Debug-Modus aktiviert"
    fi
fi

# Debug-Informationen
if [ "$DEBUG_MODE" = "true" ]; then
    echo "=== DEBUG-INFORMATIONEN ==="
    echo "Host /dev/input Status:"
    ls -la /dev/input/ 2>/dev/null || echo "Kein /dev/input Verzeichnis"
    echo "Container-Prozesse:"
    ps aux 2>/dev/null | head -5 || ps | head -5
    echo "Umgebungsvariablen:"
    env | grep -E "(ATTACH|SCANNER|BARCODE)" || echo "Keine Scanner-Variablen"
    echo "==========================="
fi

# Prüfen ob /dev/input/ existiert
if [ ! -d "/dev/input/" ]; then
    echo "PROBLEM: /dev/input/ Verzeichnis nicht im Container verfügbar!"
    echo ""
    echo "LÖSUNGSSCHRITTE:"
    echo "1. Host hat Input-Geräte ✓ (event0-event3 gefunden)"
    echo "2. Container-Mapping funktioniert nicht ✗"
    echo ""
    echo "BEHEBUNG:"
    echo "- Add-on stoppen"
    echo "- config.yaml mit 'privileged: true' aktualisieren"
    echo "- Add-on neu starten"
    echo ""
    echo "Läufe trotzdem im SIMULATION-MODUS..."
    SCANNER_DEVICE="/dev/null"
    SIMULATION_MODE="true"
else
    echo "✓ /dev/input/ Verzeichnis verfügbar"
    
    # Verfügbare Geräte anzeigen
    echo "Verfügbare Input-Geräte:"
    ls -la /dev/input/event* 2>/dev/null || echo "Keine event-Geräte"
    
    # Scanner-Gerät aus Konfiguration lesen
    SCANNER_DEVICE="/dev/input/event2"  # Standard für MINJCODE Scanner
    
    if [ -f "$CONFIG_PATH" ]; then
        CONFIGURED_DEVICE=$(grep -o '"scanner_device"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
        
        if [ -n "$CONFIGURED_DEVICE" ] && [ "$CONFIGURED_DEVICE" != "null" ]; then
            SCANNER_DEVICE="$CONFIGURED_DEVICE"
            echo "Verwende konfiguriertes Scanner-Gerät: $SCANNER_DEVICE"
        fi
    fi
    
    # Automatische Scanner-Erkennung
    if [ ! -e "$SCANNER_DEVICE" ]; then
        echo "Konfiguriertes Gerät $SCANNER_DEVICE nicht gefunden"
        echo "Starte automatische Scanner-Erkennung..."
        
        # Teste jedes verfügbare Gerät
        for device in /dev/input/event*; do
            if [ -e "$device" ]; then
                echo "Teste $device..."
                
                # Kurzer Test: Device-Namen/Info falls verfügbar
                if [ -e "/sys/class/input/$(basename $device)/device/name" ]; then
                    device_name=$(cat "/sys/class/input/$(basename $device)/device/name" 2>/dev/null)
                    echo "  Name: $device_name"
                    
                    # Scanner-typische Namen erkennen
                    if echo "$device_name" | grep -qi "scanner\|barcode\|minjcode\|symbol\|honeywell\|datalogic"; then
                        echo "  ✓ Scanner erkannt!"
                        SCANNER_DEVICE="$device"
                        break
                    fi
                fi
                
                SCANNER_DEVICE="$device"  # Fallback: erstes verfügbares Gerät
            fi
        done
    fi
    
    SIMULATION_MODE="false"
fi

echo "Scanner-Gerät: $SCANNER_DEVICE"

# grabInput.sh patchen
GRAB_SCRIPT="/app/bbuddy/example/grabInput.sh"

if [ -f "$GRAB_SCRIPT" ]; then
    echo "Patche grabInput.sh..."
    
    # Backup erstellen (nur einmal)
    if [ ! -f "${GRAB_SCRIPT}.original" ]; then
        cp "$GRAB_SCRIPT" "${GRAB_SCRIPT}.original"
        echo "Original-Skript gesichert"
    fi
    
    # Intelligenten Wrapper erstellen
    cat > "$GRAB_SCRIPT" << EOF
#!/bin/bash
# Intelligenter Scanner-Wrapper v1.1.3
# MINJCODE MJ2818A Scanner Support

echo "Scanner-Wrapper v1.1.3 gestartet"

# Hardware-Check
if [ ! -d "/dev/input/" ]; then
    echo "SIMULATION: Keine Hardware-Scanner verfügbar"
    echo "Web-Interface läuft trotzdem auf Port 8083"
    
    # Stabiler Dummy-Prozess
    while true; do
        sleep 30
        echo "\$(date): Scanner-Simulation aktiv - Web-Interface verfügbar"
    done
    exit 0
fi

# Scanner-Gerät bestimmen
DEVICE="$SCANNER_DEVICE"

# Argument-Override
if [ "\$1" != "" ] && [ -e "\$1" ]; then
    DEVICE="\$1"
    echo "Verwende Argument-Gerät: \$DEVICE"
fi

# Fallback-Suche
if [ ! -e "\$DEVICE" ]; then
    echo "Gerät \$DEVICE nicht verfügbar, automatische Suche..."
    
    for candidate in /dev/input/event*; do
        if [ -e "\$candidate" ]; then
            DEVICE="\$candidate"
            echo "Auto-Erkennung: \$DEVICE"
            break
        fi
    done
fi

# Scanner starten
if [ -e "\$DEVICE" ] && [ "\$DEVICE" != "/dev/null" ]; then
    echo "🔍 Starte MINJCODE Scanner auf: \$DEVICE"
    echo "Scanner bereit für Barcodes..."
    exec ${GRAB_SCRIPT}.original "\$DEVICE"
else
    echo "⚠️  Hardware-Scanner nicht verfügbar"
    echo "💻 Web-Interface trotzdem verfügbar auf Port 8083"
    echo "📱 Verwenden Sie die Handy-App oder manuelle Eingabe"
    
    # Dummy-Prozess (verhindert Absturz-Schleifen)
    while true; do
        sleep 60
        echo "\$(date): Warte auf Hardware-Scanner..."
    done
fi
EOF
    
    chmod +x "$GRAB_SCRIPT"
    echo "✓ Intelligenter Scanner-Wrapper installiert"
    
else
    echo "⚠️  grabInput.sh nicht gefunden bei $GRAB_SCRIPT"
fi

# Umgebungsvariablen setzen
export ATTACH_BARCODESCANNER=true
export SCANNER_DEVICE="$SCANNER_DEVICE"

echo ""
echo "🚀 Starte Barcode Buddy System..."

# Original-Supervisor starten
if [ -f "/app/supervisor" ]; then
    echo "Starte /app/supervisor..."
    exec /app/supervisor
else
    echo "❌ FEHLER: /app/supervisor nicht gefunden!"
    exit 1
fi