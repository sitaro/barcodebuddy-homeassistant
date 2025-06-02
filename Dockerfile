# Dockerfile - Einfach und sauber für Scanner event4
FROM f0rc3/barcodebuddy:latest

# Home Assistant Add-on Labels
LABEL \
    io.hass.version="1.1.2" \
    io.hass.type="addon" \
    io.hass.arch="armhf|armv7|aarch64|amd64|i386"

# USB-Scanner aktivieren (event4 wird automatisch verwendet)
ENV ATTACH_BARCODESCANNER=true

# Installiere jq für JSON-Parsing (falls nicht vorhanden)
RUN apk add --no-cache jq 2>/dev/null || apt-get update && apt-get install -y jq 2>/dev/null || true

# Startup-Skript hinzufügen
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

# Unser Startup-Skript als Entrypoint
CMD ["/usr/local/bin/run.sh"]