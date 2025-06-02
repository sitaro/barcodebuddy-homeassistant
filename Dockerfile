# Dockerfile - Scanner-Patch für MINJCODE MJ2818A v1.1.8
FROM f0rc3/barcodebuddy:latest

# Home Assistant Add-on Labels
LABEL \
    io.hass.version="1.1.8" \
    io.hass.type="addon" \
    io.hass.arch="armhf|armv7|aarch64|amd64|i386"

# USB-Scanner aktivieren
ENV ATTACH_BARCODESCANNER=true

# Scanner-Patch-Skript hinzufügen
COPY patch-scanner.sh /usr/local/bin/patch-scanner.sh
RUN chmod +x /usr/local/bin/patch-scanner.sh

# Patch beim Start ausführen, dann Original-Supervisor starten
CMD ["/usr/local/bin/patch-scanner.sh"]