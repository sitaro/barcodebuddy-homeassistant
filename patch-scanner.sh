#!/bin/bash

# patch-scanner.sh v1.1.6 - Mit Authentication Fix

echo "=== Barcode Buddy Scanner-Patch v1.1.6 (Authentication Fix) ==="

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

# grabInput.sh patchen (wie vorher)
GRAB_SCRIPT="/app/bbuddy/example/grabInput.sh"

if [ -f "$GRAB_SCRIPT" ]; then
    echo "Patche grabInput.sh..."
    
    # Original sichern
    if [ ! -f "${GRAB_SCRIPT}.original" ]; then
        cp "$GRAB_SCRIPT" "${GRAB_SCRIPT}.original"
        echo "Original-Skript gesichert"
    fi
    
    # Korrigierten Wrapper erstellen
    cat > "$GRAB_SCRIPT" << 'EOF'
#!/bin/bash
# Scanner-Wrapper v1.1.6 - Exec + Auth Fix

echo "Scanner-Wrapper v1.1.6 gestartet (Exec + Auth Fix)"

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
DEVICE="/dev/input/event2"

if [ "$1" != "" ] && [ -e "$1" ]; then
    DEVICE="$1"
    echo "Verwende Argument-Gerät: $DEVICE"
fi

if [ ! -e "$DEVICE" ]; then
    echo "Auto-Erkennung..."
    for candidate in /dev/input/event*; do
        if [ -e "$candidate" ]; then
            DEVICE="$candidate"
            echo "Auto-Erkennung: $DEVICE"
            break
        fi
    done
fi

if [ ! -e "$DEVICE" ] || [ "$DEVICE" = "/dev/null" ]; then
    echo "⚠️  Hardware-Scanner nicht verfügbar"
    
    while true; do
        sleep 60
        echo "$(date +%H:%M): Warte auf Hardware-Scanner..."
    done
    exit 0
fi

echo "🔍 MINJCODE Scanner bereit: $DEVICE"

ORIGINAL_SCRIPT="/app/bbuddy/example/grabInput.sh.original"

if [ -f "$ORIGINAL_SCRIPT" ]; then
    chmod +x "$ORIGINAL_SCRIPT"
    echo "✅ Starte Original-Scanner für: $DEVICE"
    echo "[ScannerConnection] Erwartet Scanner-Input..."
    
    exec "$ORIGINAL_SCRIPT" "$DEVICE"
else
    echo "❌ Original-Skript nicht gefunden"
    
    while true; do
        sleep 60
        echo "$(date +%H:%M): Fallback-Scanner aktiv"
    done
fi
EOF
    
    chmod +x "$GRAB_SCRIPT"
    echo "✅ Scanner-Wrapper v1.1.6 installiert"
else
    echo "⚠️  grabInput.sh nicht gefunden"
fi

# NEU: Authentication-Fix für Barcode Buddy
echo ""
echo "🔐 Konfiguriere Authentication..."

# Barcode Buddy Config-Datei erstellen/anpassen
BB_CONFIG="/app/bbuddy/config.php"

# Backup falls vorhanden
[ -f "$BB_CONFIG" ] && cp "$BB_CONFIG" "${BB_CONFIG}.backup"

# Neue Config mit deaktivierter Authentication
cat > "$BB_CONFIG" << 'BBCONFIG'
<?php
// Barcode Buddy Config - Home Assistant Add-on v1.1.6
// Authentication komplett deaktiviert für Add-on

define("DISABLE_AUTHENTICATION", true);
define("LOGIN_REQUIRED", false);
$LOGIN_MODE = false;
$require_auth = false;

// Config-Array
$config = array();
$config['DISABLE_AUTHENTICATION'] = true;
$config['LOGIN_REQUIRED'] = false;
$config['DB_PATH'] = '/config/barcodebuddy.db';
$config['API_KEY'] = '';

// Home Assistant Add-on spezifische Settings
if (getenv('DEBUG_MODE') === 'true') {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
}

$config['PORT'] = 80;
$config['LISTEN'] = '0.0.0.0';
$config['CURL_ALLOW_INSECURE_SSL_CA'] = false;
$config['CURL_ALLOW_INSECURE_SSL_HOST'] = false;

?>
BBCONFIG

echo "✅ Barcode Buddy Authentication deaktiviert"

# .htaccess bereinigen
if [ -f "/app/bbuddy/.htaccess" ]; then
    sed -i '/AuthType/d; /AuthName/d; /AuthUserFile/d; /Require/d' /app/bbuddy/.htaccess
    echo "✅ .htaccess bereinigt"
fi

# PHP-Sessions löschen
rm -f /tmp/sess_* /var/lib/php/sessions/sess_* 2>/dev/null || true

# Web-Interface Start-Hook hinzufügen
echo "Erstelle Web-Interface-Monitor..."
cat > /usr/local/bin/web-monitor.sh << 'EOF'
#!/bin/bash
# Web-Interface Monitor v1.1.6

sleep 10  # Warten bis Services gestartet

while true; do
    # Prüfe ob Port 80 lauscht
    if ! netstat -tln 2>/dev/null | grep -q ":80 " && ! ss -tln 2>/dev/null | grep -q ":80 "; then
        echo "$(date): ❌ Port 80 nicht verfügbar - versuche Nginx-Neustart"
        
        # Nginx neustarten falls möglich
        if command -v nginx >/dev/null 2>&1; then
            nginx -s reload 2>/dev/null || nginx 2>/dev/null &
        fi
    fi
    
    # Prüfe Web-Interface
    if ! curl -f http://localhost:80 >/dev/null 2>&1; then
        echo "$(date): ⚠️  Web-Interface nicht erreichbar"
        
        # Debugging-Info sammeln
        if [ -f "/var/log/nginx/error.log" ]; then
            echo "Nginx-Errors:"
            tail -3 /var/log/nginx/error.log 2>/dev/null || echo "Keine Logs"
        fi
    else
        echo "$(date): ✅ Web-Interface erreichbar"
    fi
    
    sleep 120  # Alle 2 Minuten prüfen
done
EOF

chmod +x /usr/local/bin/web-monitor.sh

# Umgebungsvariablen setzen
export ATTACH_BARCODESCANNER=true
export SCANNER_DEVICE="$SCANNER_DEVICE"

echo ""
echo "🚀 Starte Barcode Buddy System v1.1.6..."

# Web-Monitor im Hintergrund starten
/usr/local/bin/web-monitor.sh &

# Original-Supervisor starten
if [ -f "/app/supervisor" ]; then
    echo "Starte /app/supervisor..."
    exec /app/supervisor
else
    echo "❌ FEHLER: /app/supervisor nicht gefunden!"
    exit 1
fi