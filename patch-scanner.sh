#!/bin/bash

# patch-scanner.sh v1.2.3 - Robustes Config-Parsing

echo "=== Barcode Buddy Scanner-Patch v1.2.3 (Robustes Config-Parsing) ==="

# Funktion zum sicheren JSON-Parsing
parse_json_value() {
    local json_file="$1"
    local key="$2"
    local default_value="$3"
    
    if [ ! -f "$json_file" ]; then
        echo "$default_value"
        return
    fi
    
    # Versuche jq zuerst (falls verfügbar)
    if command -v jq >/dev/null 2>&1; then
        local value=$(jq -r ".$key // \"$default_value\"" "$json_file" 2>/dev/null)
        if [ "$value" != "null" ] && [ -n "$value" ]; then
            echo "$value"
        else
            echo "$default_value"
        fi
        return
    fi
    
    # Fallback: Verbessertes grep/sed
    local pattern="\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
    local value=$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$json_file" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    
    if [ -n "$value" ] && [ "$value" != "null" ]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

# Funktion für Boolean-Werte
parse_json_bool() {
    local json_file="$1"
    local key="$2"
    local default_value="$3"
    
    if [ ! -f "$json_file" ]; then
        echo "$default_value"
        return
    fi
    
    # Versuche jq zuerst
    if command -v jq >/dev/null 2>&1; then
        local value=$(jq -r ".$key // $default_value" "$json_file" 2>/dev/null)
        echo "$value"
        return
    fi
    
    # Fallback: grep für boolean
    if grep -q "\"$key\"[[:space:]]*:[[:space:]]*true" "$json_file" 2>/dev/null; then
        echo "true"
    elif grep -q "\"$key\"[[:space:]]*:[[:space:]]*false" "$json_file" 2>/dev/null; then
        echo "false"
    else
        echo "$default_value"
    fi
}

# Standard-Werte definieren
DEFAULT_GROCY_URL="http://ha.mathops.de:8123/hassio/ingress/a0d7b954_grocy"
DEFAULT_API_KEY="SgEQWmOYXJvyweDV9qnhI9tZGjrW4BVxaQXSYbiLZvVfmEJeNy"
DEFAULT_USERNAME="mathias"
DEFAULT_SCANNER_DEVICE="/dev/input/event3"

# Konfigurationsdateien suchen
CONFIG_PATH=""
for path in "/data/options.json" "/config/options.json" "/addon_configs/*/options.json"; do
    if [ -f "$path" ]; then
        CONFIG_PATH="$path"
        echo "📄 Konfigurationsdatei gefunden: $CONFIG_PATH"
        break
    fi
done

if [ -z "$CONFIG_PATH" ]; then
    echo "⚠️  Keine Konfigurationsdatei gefunden - verwende Standard-Werte"
    CONFIG_PATH="/dev/null"
else
    echo "📋 Konfigurationsinhalt:"
    cat "$CONFIG_PATH" | head -20
    echo ""
fi

# Konfigurationswerte parsen
echo "🔧 Parse Konfigurationswerte..."

DEBUG_MODE=$(parse_json_bool "$CONFIG_PATH" "debug" "false")
GROCY_SERVER_URL=$(parse_json_value "$CONFIG_PATH" "grocy_server_url" "$DEFAULT_GROCY_URL")
GROCY_API_KEY=$(parse_json_value "$CONFIG_PATH" "grocy_api_key" "$DEFAULT_API_KEY")
GROCY_USERNAME=$(parse_json_value "$CONFIG_PATH" "grocy_username" "$DEFAULT_USERNAME")
SCANNER_DEVICE=$(parse_json_value "$CONFIG_PATH" "scanner_device" "$DEFAULT_SCANNER_DEVICE")
AUTO_SETUP_GROCY=$(parse_json_bool "$CONFIG_PATH" "auto_setup_grocy" "true")
USE_INGRESS=$(parse_json_bool "$CONFIG_PATH" "use_ingress" "true")
REQUIRE_API_KEY=$(parse_json_bool "$CONFIG_PATH" "require_api_key" "false")
DISABLE_AUTH=$(parse_json_bool "$CONFIG_PATH" "disable_auth" "true")

# Debug-Ausgabe der gelesenen Werte
echo ""
echo "📊 Gelesene Konfigurationswerte:"
echo "  Debug-Modus: $DEBUG_MODE"
echo "  Grocy-URL: $GROCY_SERVER_URL"
echo "  API-Key: ${GROCY_API_KEY:0:10}..." # Nur erste 10 Zeichen zeigen
echo "  Username: $GROCY_USERNAME"
echo "  Scanner-Device: $SCANNER_DEVICE"
echo "  Auto-Setup: $AUTO_SETUP_GROCY"
echo "  Use-Ingress: $USE_INGRESS"
echo "  Require-API-Key: $REQUIRE_API_KEY"
echo "  Disable-Auth: $DISABLE_AUTH"

# Automatische Ingress-Erkennung
if echo "$GROCY_SERVER_URL" | grep -q "hassio/ingress"; then
    USE_INGRESS="true"
    echo "🔗 Ingress-URL automatisch erkannt"
fi

# Erweiterte Debug-Ausgabe
if [ "$DEBUG_MODE" = "true" ]; then
    echo ""
    echo "=== DEBUG-INFORMATIONEN ==="
    echo "Verfügbare /dev/input Geräte:"
    ls -la /dev/input/ 2>/dev/null || echo "Keine /dev/input Geräte"
    echo "Aktuelle Umgebungsvariablen:"
    env | grep -i "grocy\|scanner\|barcode" || echo "Keine relevanten Umgebungsvariablen"
    echo "=========================="
fi

# Scanner-Gerät validieren
if [ ! -e "$SCANNER_DEVICE" ]; then
    echo "⚠️  Konfiguriertes Scanner-Gerät nicht gefunden: $SCANNER_DEVICE"
    echo "🔍 Suche nach verfügbaren Alternativen..."
    
    for candidate in /dev/input/event*; do
        if [ -e "$candidate" ]; then
            echo "Alternative gefunden: $candidate"
            SCANNER_DEVICE="$candidate"
            break
        fi
    done
fi

echo "✅ Finale Scanner-Konfiguration: $SCANNER_DEVICE"

# grabInput.sh patchen
GRAB_SCRIPT="/app/bbuddy/example/grabInput.sh"

if [ -f "$GRAB_SCRIPT" ]; then
    echo "🔧 Patche grabInput.sh..."
    
    if [ ! -f "${GRAB_SCRIPT}.original" ]; then
        cp "$GRAB_SCRIPT" "${GRAB_SCRIPT}.original"
        echo "Original-Skript gesichert"
    fi
    
    cat > "$GRAB_SCRIPT" << EOF
#!/bin/bash
# Scanner-Wrapper v1.2.3 - Mit robuster Konfiguration

echo "Scanner-Wrapper v1.2.3 gestartet (Konfigurierter Device: $SCANNER_DEVICE)"

# Hardware-Check
if [ ! -d "/dev/input/" ]; then
    echo "SIMULATION: Keine Hardware-Scanner verfügbar"
    while true; do
        sleep 60
        echo "\$(date +%H:%M): Scanner-Simulation aktiv"
    done
    exit 0
fi

# Scanner-Gerät bestimmen - Priorität: Argument > Konfiguration > Auto-Erkennung
DEVICE="$SCANNER_DEVICE"

if [ "\$1" != "" ] && [ -e "\$1" ]; then
    DEVICE="\$1"
    echo "Verwende Argument-Gerät: \$DEVICE"
elif [ -e "$SCANNER_DEVICE" ]; then
    DEVICE="$SCANNER_DEVICE"
    echo "Verwende konfiguriertes Gerät: \$DEVICE"
else
    echo "Auto-Erkennung gestartet..."
    for candidate in /dev/input/event*; do
        if [ -e "\$candidate" ]; then
            DEVICE="\$candidate"
            echo "Auto-Erkennung erfolgreich: \$DEVICE"
            break
        fi
    done
fi

if [ ! -e "\$DEVICE" ] || [ "\$DEVICE" = "/dev/null" ]; then
    echo "⚠️  Hardware-Scanner nicht verfügbar"
    echo "Konfiguriert: $SCANNER_DEVICE"
    echo "Verfügbare Geräte:"
    ls -la /dev/input/event* 2>/dev/null || echo "Keine event-Geräte"
    while true; do
        sleep 60
        echo "\$(date +%H:%M): Warte auf Hardware-Scanner..."
    done
    exit 0
fi

echo "🔍 MINJCODE Scanner bereit: \$DEVICE"

ORIGINAL_SCRIPT="/app/bbuddy/example/grabInput.sh.original"

if [ -f "\$ORIGINAL_SCRIPT" ]; then
    chmod +x "\$ORIGINAL_SCRIPT"
    echo "✅ Starte Original-Scanner für: \$DEVICE"
    echo "[ScannerConnection] Erwartet Scanner-Input..."
    exec "\$ORIGINAL_SCRIPT" "\$DEVICE"
else
    echo "❌ Original-Skript nicht gefunden"
    while true; do
        sleep 60
        echo "\$(date +%H:%M): Fallback-Scanner aktiv"
    done
fi
EOF
    
    chmod +x "$GRAB_SCRIPT"
    echo "✅ Scanner-Wrapper v1.2.3 installiert"
else
    echo "⚠️  grabInput.sh nicht gefunden"
fi

# API-URL konfigurieren
if [ "$USE_INGRESS" = "true" ]; then
    echo "🔗 Ingress-Modus aktiviert"
    GROCY_API_URL="${GROCY_SERVER_URL}/api/"
    GROCY_BASE_URL="$GROCY_SERVER_URL"
else
    echo "🔗 Standard-Modus aktiviert"
    GROCY_API_URL="${GROCY_SERVER_URL}/api/"
    GROCY_BASE_URL="$GROCY_SERVER_URL"
fi

echo "📡 API-URL: $GROCY_API_URL"

# Grocy-Integration Setup
echo ""
echo "🏪 Konfiguriere Grocy-Integration..."

if [ -n "$GROCY_API_KEY" ] && [ "$GROCY_API_KEY" != "" ]; then
    # MHD-Konfiguration in Grocy setzen
    echo "🗓️  Konfiguriere Standard-MHD-Werte..."
    
    curl -s -X PUT \
        -H "GROCY-API-KEY: $GROCY_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"value": "30"}' \
        "${GROCY_API_URL}user-settings/stock_default_best_before_days" >/dev/null 2>&1
    
    curl -s -X PUT \
        -H "GROCY-API-KEY: $GROCY_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"value": "1"}' \
        "${GROCY_API_URL}user-settings/stock_auto_add_products_below_min_stock_amount" >/dev/null 2>&1
        
    echo "✅ MHD-Konfiguration abgeschlossen"
fi

# Barcode Buddy Config erstellen
BB_CONFIG="/app/bbuddy/config.php"
[ -f "$BB_CONFIG" ] && cp "$BB_CONFIG" "${BB_CONFIG}.backup"

cat > "$BB_CONFIG" << BBCONFIG
<?php
// Barcode Buddy Config - Home Assistant Add-on v1.2.3
// Robuste Konfiguration mit Add-on Integration

define("DISABLE_AUTHENTICATION", $DISABLE_AUTH);
define("LOGIN_REQUIRED", !$DISABLE_AUTH);
\$LOGIN_MODE = !$DISABLE_AUTH;
\$require_auth = !$DISABLE_AUTH;

// Config-Array
\$config = array();
\$config['DISABLE_AUTHENTICATION'] = $DISABLE_AUTH;
\$config['LOGIN_REQUIRED'] = !$DISABLE_AUTH;
\$config['DB_PATH'] = '/config/barcodebuddy.db';
\$config['API_KEY'] = '$REQUIRE_API_KEY' ? 'ha-addon-key' : '';

// Grocy-Integration Einstellungen
\$config['GROCY_API_URL'] = '$GROCY_API_URL';
\$config['GROCY_API_KEY'] = '$GROCY_API_KEY';
\$config['GROCY_BASE_URL'] = '$GROCY_BASE_URL';

// MHD-Standard-Einstellungen
\$config['DEFAULT_BEST_BEFORE_DAYS'] = 30;
\$config['AUTO_ADD_PRODUCTS'] = true;
\$config['DEFAULT_PRODUCT_GROUP'] = 'Lebensmittel';

// Ingress-spezifische Einstellungen
\$config['USE_GROCY_INGRESS'] = $USE_INGRESS;
if ($USE_INGRESS) {
    \$config['GROCY_INGRESS_URL'] = '$GROCY_SERVER_URL';
}

// Home Assistant Add-on Settings
if ('$DEBUG_MODE' === 'true') {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
    \$config['DEBUG_MODE'] = true;
}

\$config['PORT'] = 80;
\$config['LISTEN'] = '0.0.0.0';
\$config['CURL_ALLOW_INSECURE_SSL_CA'] = false;
\$config['CURL_ALLOW_INSECURE_SSL_HOST'] = false;

// Add-on spezifische Werte
\$config['SCANNER_DEVICE'] = '$SCANNER_DEVICE';
\$config['AUTO_SETUP_GROCY'] = $AUTO_SETUP_GROCY;

?>
BBCONFIG

echo "✅ Barcode Buddy Config v1.2.3 erstellt"

# Grocy-Verbindung testen
if [ -n "$GROCY_API_KEY" ] && [ "$GROCY_API_KEY" != "" ]; then
    echo ""
    echo "🔗 Teste Grocy-Verbindung..."
    
    GROCY_TEST=$(curl -s -H "GROCY-API-KEY: $GROCY_API_KEY" -H "Accept: application/json" "${GROCY_API_URL}system/info" 2>/dev/null)
    
    if echo "$GROCY_TEST" | grep -q "grocy_version\|version"; then
        echo "✅ Grocy-Verbindung erfolgreich!"
        GROCY_VERSION=$(echo "$GROCY_TEST" | grep -o '"grocy_version":"[^"]*"' | cut -d'"' -f4)
        echo "📦 Grocy Version: $GROCY_VERSION"
    else
        echo "⚠️  Grocy-Verbindung fehlgeschlagen"
        echo "🔧 Debug-URL: $GROCY_API_URL"
        echo "🔧 Response: $GROCY_TEST"
    fi
else
    echo "⚠️  Kein Grocy API-Key konfiguriert"
fi

# Authentication konfigurieren
echo ""
echo "🔐 Konfiguriere Authentication (Disable: $DISABLE_AUTH)..."

if [ -f "/app/bbuddy/.htaccess" ]; then
    if [ "$DISABLE_AUTH" = "true" ]; then
        sed -i '/AuthType/d; /AuthName/d; /AuthUserFile/d; /Require/d' /app/bbuddy/.htaccess
        echo "✅ .htaccess bereinigt (Auth deaktiviert)"
    else
        echo "ℹ️  .htaccess belassen (Auth aktiviert)"
    fi
fi

rm -f /tmp/sess_* /var/lib/php/sessions/sess_* 2>/dev/null || true

# Web-Monitor erstellen
echo "📡 Erstelle Web-Interface-Monitor..."
cat > /usr/local/bin/web-monitor.sh << 'EOF'
#!/bin/bash
# Web-Interface Monitor v1.2.3

sleep 10

while true; do
    # Port 80 prüfen
    if ! netstat -tln 2>/dev/null | grep -q ":80 " && ! ss -tln 2>/dev/null | grep -q ":80 "; then
        echo "$(date): ❌ Port 80 nicht verfügbar - Service-Neustart"
        if command -v nginx >/dev/null 2>&1; then
            nginx -s reload 2>/dev/null || nginx 2>/dev/null &
        fi
    fi
    
    # Web-Interface testen
    if ! curl -f http://localhost:80 >/dev/null 2>&1; then
        echo "$(date): ⚠️  Web-Interface nicht erreichbar"
    else
        if [ "$DEBUG_MODE" = "true" ]; then
            echo "$(date): ✅ Web-Interface erreichbar"
        fi
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
export DEBUG_MODE="$DEBUG_MODE"

echo ""
echo "🚀 Starte Barcode Buddy System v1.2.3..."
echo "📊 Grocy-Integration: $([[ -n "$GROCY_API_KEY" ]] && echo "✅ Aktiviert" || echo "❌ API-Key erforderlich")"
echo "🎯 Scanner-Device: $SCANNER_DEVICE"
echo "👤 Grocy-User: $GROCY_USERNAME"
echo "🔗 Grocy-URL: $GROCY_SERVER_URL"
echo "🗓️  Standard-MHD: 30 Tage"
echo "🔐 Authentication: $([[ "$DISABLE_AUTH" = "true" ]] && echo "Deaktiviert" || echo "Aktiviert")"
echo "🐛 Debug-Modus: $DEBUG_MODE"

# Web-Monitor im Hintergrund starten
if [ "$DEBUG_MODE" = "true" ]; then
    /usr/local/bin/web-monitor.sh &
fi

# Original-Supervisor starten
if [ -f "/app/supervisor" ]; then
    echo "▶️  Starte /app/supervisor..."
    exec /app/supervisor
else
    echo "❌ FEHLER: /app/supervisor nicht gefunden!"
    echo "Verfügbare Dateien in /app:"
    ls -la /app/ 2>/dev/null || echo "Verzeichnis /app nicht verfügbar"
    exit 1
fi