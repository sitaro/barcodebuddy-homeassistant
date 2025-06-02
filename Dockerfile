# Dockerfile - Einfach und sauber für Scanner event4
FROM f0rc3/barcodebuddy:latest

# Home Assistant Add-on Labels
LABEL \
    io.hass.version="1.1.1" \
    io.hass.type="addon" \
    io.hass.arch="armhf|armv7|aarch64|amd64|i386"

# USB-Scanner aktivieren (event4 wird automatisch verwendet)
ENV ATTACH_BARCODESCANNER=true

# Startup-Skript hinzufügen das die Home Assistant Konfiguration liest
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

# Unser eigenes Startup-Skript verwenden
CMD ["/usr/local/bin/run.sh"]