# Dockerfile - Basiert auf dem originalen Barcode Buddy Image
FROM f0rc3/barcodebuddy:latest

# Home Assistant Add-on Labels (erforderlich)
LABEL \
    io.hass.version="1.0.3" \
    io.hass.type="addon" \
    io.hass.arch="armhf|armv7|aarch64|amd64|i386"

# Bashio für Home Assistant Integration installieren (falls nicht vorhanden)
RUN apk add --no-cache bashio jq curl || echo "Packages may already be available"

# USB-Scanner Umgebungsvariable setzen
ENV ATTACH_BARCODESCANNER=true

# Stelle sicher, dass Input-Devices richtig erkannt werden
RUN apk add --no-cache evtest udev || echo "Input tools may already be available"

# Container normal starten (verwendet den Standard-Startbefehl des Base-Images)
#CMD ["/init"]
