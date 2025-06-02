#!/bin/bash

# patch-scanner.sh v1.1.9 - Syntax-Fix und Grocy-URL-Korrektur

echo "=== Barcode Buddy Scanner-Patch v1.1.9 (Grocy-Ingress-Fix) ==="

# Debug-Modus und Konfiguration lesen
DEBUG_MODE="false"
CONFIG_PATH="/data/options.json"

# Grocy-Einstellungen (Standard-Werte mit korrekter URL)
GROCY_SERVER_URL="http://ha.mathops.de:8123/hassio/ingress/a0d7b954_grocy"
GROCY_API_KEY=""
GROCY_USERNAME="admin"
AUTO_SETUP_GROCY="true"
USE_INGRESS="false"

if [ -f "$CONFIG_PATH" ]; then
    if grep -q '"debug"[[:space:]]*:[[:space:]]*true' "$CONFIG_PATH" 2>/dev/null; then
        DEBUG_MODE="true"
        echo "Debug-Modus aktiviert"
    fi
    
    # Grocy-Konfiguration aus Add-on-Optionen lesen (mit Ingress-Support)
    CONFIGURED_URL=$(grep -o '"grocy_server_url"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    if [ -n "$CONFIGURED_URL" ] && [ "$CONFIGURED_URL" != "null" ]; then
        GROCY_SERVER_URL="$CONFIGURED_URL"
    fi
    
    GROCY_API_KEY=$(grep -o '"grocy_api_key"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    
    GROCY_USERNAME=$(grep -o '"grocy_username"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    [ -z "$GROCY_USERNAME" ] && GROCY_USERNAME="admin"
    
    if grep -q '"use_ingress"[[:space:]]*:[[:space:]]*true' "$CONFIG_PATH" 2>/dev/null; then
        USE_INGRESS="true"
    fi
    
    if grep -q '"auto_setup_grocy"[[:space:]]*:[[:space:]]*true' "$CONFIG_PATH" 2>/dev/null; then
        AUTO_SETUP_GROCY="true"
    fi
fi

# Automatische Ingress-Erkennung (KORRIGIERT)
if echo "$GROCY_SERVER_URL" | grep -q "hassio/ingress"; then
    USE_INGRESS="true"
    echo "🔗 Ingress-URL automatisch erkannt"
fi

# Scanner-Gerät konfigurieren
SCANNER_DEVICE="/dev/input/event2"
if [ -f "$CONFIG_PATH" ]; then
    CONFIGURED_DEVICE=$(grep -o '"scanner_device"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    if [ -n "$CONFIGURED_DEVICE" ] && [ "$CONFIGURED_DEVICE" != "null" ]; then
        SCANNER_DEVICE="$CONFIGURED_DEVICE"
    fi
fi

echo "Scanner-Gerät: $SCANNER_DEVICE"
echo "Grocy-Server: $GROCY_SERVER_URL"
echo "Ingress-Modus: $USE_INGRESS"

# grabInput.sh patchen
GRAB_SCRIPT="/app/bbuddy/example/grabInput.sh"

if [ -f "$GRAB_SCRIPT" ]; then
    echo "Patche grabInput.sh..."
    
    if [ ! -f "${GRAB_SCRIPT}.original" ]; then
        cp "$GRAB_SCRIPT" "${GRAB_SCRIPT}.original"
        echo "Original-Skript gesichert"
    fi
    
    cat > "$GRAB_SCRIPT" << 'EOF'
#!/bin/bash
# Scanner-Wrapper v1.1.9 - Syntax-Fix

echo "Scanner-Wrapper v1.1.9 gestartet (Syntax-Fix)"

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
    echo "✅ Scanner-Wrapper v1.1.9 installiert"
else
    echo "⚠️  grabInput.sh nicht gefunden"
fi

# Grocy-Integration Setup (SYNTAX KORRIGIERT)
echo ""
echo "🏪 Konfiguriere Grocy-Integration (Ingress-Support)..."

# Ingress-spezifische API-URL-Behandlung  
if [ "$USE_INGRESS" = "true" ]; then
    echo "🔗 Ingress-Modus erkannt"
    GROCY_API_URL="${GROCY_SERVER_URL}/api/"
    GROCY_BASE_URL="$GROCY_SERVER_URL"
    echo "📡 Ingress API-URL: $GROCY_API_URL"
else
    echo "🔗 Standard-Modus - direkter Port"
    GROCY_API_URL="${GROCY_SERVER_URL}/api/"
    GROCY_BASE_URL="$GROCY_SERVER_URL"
fi

# Barcode Buddy Config erstellen
BB_CONFIG="/app/bbuddy/config.php"
[ -f "$BB_CONFIG" ] && cp "$BB_CONFIG" "${BB_CONFIG}.backup"

cat > "$BB_CONFIG" << BBCONFIG
<?php
// Barcode Buddy Config - Home Assistant Add-on v1.1.9
// Authentication deaktiviert + Grocy-Ingress-Integration

define("DISABLE_AUTHENTICATION", true);
define("LOGIN_REQUIRED", false);
\$LOGIN_MODE = false;
\$require_auth = false;

// Config-Array
\$config = array();
\$config['DISABLE_AUTHENTICATION'] = true;
\$config['LOGIN_REQUIRED'] = false;
\$config['DB_PATH'] = '/config/barcodebuddy.db';
\$config['API_KEY'] = '';

// Grocy-Integration Einstellungen v1.1.9
\$config['GROCY_API_URL'] = '$GROCY_API_URL';
\$config['GROCY_API_KEY'] = '$GROCY_API_KEY';
\$config['GROCY_BASE_URL'] = '$GROCY_BASE_URL';

// Ingress-spezifische Einstellungen
if (strpos('$GROCY_SERVER_URL', 'hassio/ingress') !== false) {
    \$config['USE_GROCY_INGRESS'] = true;
    \$config['GROCY_INGRESS_URL'] = '$GROCY_SERVER_URL';
} else {
    \$config['USE_GROCY_INGRESS'] = false;
}

// Home Assistant Add-on Settings
if (getenv('DEBUG_MODE') === 'true') {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
}

\$config['PORT'] = 80;
\$config['LISTEN'] = '0.0.0.0';
\$config['CURL_ALLOW_INSECURE_SSL_CA'] = false;
\$config['CURL_ALLOW_INSECURE_SSL_HOST'] = false;

?>
BBCONFIG

echo "✅ Barcode Buddy Config mit Grocy-Integration v1.1.9 erstellt"

# Grocy-Verbindung testen (Syntax korrigiert)
if [ -n "$GROCY_API_KEY" ] && [ "$GROCY_API_KEY" != "" ]; then
    echo ""
    echo "🔗 Teste Grocy-Verbindung (v1.1.9)..."
    
    if [ "$USE_INGRESS" = "true" ]; then
        echo "📡 Teste Ingress-API: $GROCY_API_URL"
        GROCY_TEST=$(curl -s -H "GROCY-API-KEY: $GROCY_API_KEY" -H "Accept: application/json" "${GROCY_API_URL}system/info" 2>/dev/null)
    else
        echo "📡 Teste Standard-API: $GROCY_API_URL"
        GROCY_TEST=$(curl -s -H "GROCY-API-KEY: $GROCY_API_KEY" "${GROCY_API_URL}system/info" 2>/dev/null)
    fi
    
    if echo "$GROCY_TEST" | grep -q "grocy_version\|version"; then
        echo "✅ Grocy-Verbindung erfolgreich!"
        GROCY_VERSION=$(echo "$GROCY_TEST" | grep -o '"grocy_version":"[^"]*"' | cut -d'"' -f4)
        echo "📦 Grocy Version: $GROCY_VERSION"
        
        if [ "$USE_INGRESS" = "true" ]; then
            echo "🔗 Ingress-Integration aktiv"
        fi
    else
        echo "⚠️  Grocy-Verbindung fehlgeschlagen"
        echo "💡 Prüfen Sie:"
        echo "   - Grocy läuft und ist erreichbar"
        echo "   - API-Key ist korrekt"
        echo "   - URL ist vollständig: $GROCY_SERVER_URL"
        echo ""
        echo "🔧 Debug-Test:"
        echo "   curl -H \"GROCY-API-KEY: $GROCY_API_KEY\" \"${GROCY_API_URL}system/info\""
    fi
else
    echo "⚠️  Kein Grocy API-Key konfiguriert"
    echo "💡 Konfigurieren Sie grocy_api_key in den Add-on-Optionen"
    echo "🔗 Ihre Grocy-URL: $GROCY_SERVER_URL"
fi

# Authentication-Fix
echo ""
echo "🔐 Konfiguriere Authentication..."

if [ -f "/app/bbuddy/.htaccess" ]; then
    sed -i '/AuthType/d; /AuthName/d; /AuthUserFile/d; /Require/d' /app/bbuddy/.htaccess
    echo "✅ .htaccess bereinigt"
fi

rm -f /tmp/sess_* /var/lib/php/sessions/sess_* 2>/dev/null || true

# Web-Monitor erstellen
echo "Erstelle Web-Interface-Monitor..."
cat > /usr/local/bin/web-monitor.sh << 'EOF'
#!/bin/bash
# Web-Interface Monitor v1.1.9

sleep 10

while true; do
    # Port 80 prüfen
    if ! netstat -tln 2>/dev/null | grep -q ":80 " && ! ss -tln 2>/dev/null | grep -q ":80 "; then
        echo "$(date): ❌ Port 80 nicht verfügbar - Nginx-Neustart"
        if command -v nginx >/dev/null 2>&1; then
            nginx -s reload 2>/dev/null || nginx 2>/dev/null &
        fi
    fi
    
    # Web-Interface testen
    if ! curl -f http://localhost:80 >/dev/null 2>&1; then
        echo "$(date): ⚠️  Web-Interface nicht erreichbar"
    else
        echo "$(date): ✅ Web-Interface erreichbar"
    fi
    
    sleep 120
done
EOF

chmod +x /usr/local/bin/web-monitor.sh

# Umgebungsvariablen setzen
export ATTACH_BARCODESCANNER=true
export SCANNER_DEVICE="$SCANNER_DEVICE"
export GROCY_API_URL="$GROCY_API_URL"
export GROCY_API_KEY="$GROCY_API_KEY"

echo ""
echo "🚀 Starte Barcode Buddy System v1.1.9..."
echo "📊 Grocy-Integration: $([[ -n "$GROCY_API_KEY" ]] && echo "Aktiviert (v1.1.9)" || echo "API-Key erforderlich")"
echo "🔗 Grocy-URL: $GROCY_SERVER_URL"

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