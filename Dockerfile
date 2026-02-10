# ===============================
#   ALPINE + noVNC + Firefox (ESR)
#   Railway Ready (PORT exposed)
# ===============================
FROM alpine:3.20

ENV TZ=Asia/Ho_Chi_Minh
ENV PORT=8080

ENV DISPLAY=:99
ENV VNC_PORT=5900

# (Tuỳ chọn) giảm rủi ro sandbox trong container/root
ENV MOZ_DISABLE_CONTENT_SANDBOX=1
ENV MOZ_DISABLE_GMP_SANDBOX=1

# -------------------------------
# Base packages (lightweight)
# -------------------------------
RUN sed -i 's/^#//' /etc/apk/repositories && \
    apk add --no-cache \
      bash ca-certificates curl tzdata \
      xvfb fluxbox x11vnc \
      dbus dbus-x11 \
      ttf-dejavu fontconfig \
      novnc websockify \
      firefox-esr && \
    ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

# Alpine novnc package thường đặt web ở /usr/share/novnc
# Tạo index.html cho tiện
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html || true

# -------------------------------
# Entrypoint
# -------------------------------
RUN cat > /usr/local/bin/start-gui.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Timezone: ${TZ}"
echo "Railway PORT: ${PORT}"
echo "DISPLAY: ${DISPLAY}"

# dbus (tránh một số cảnh báo/app cần dbus)
mkdir -p /run/dbus
dbus-daemon --system --fork || true

rm -f /tmp/.X99-lock || true
rm -rf /tmp/.X11-unix/X99 || true
mkdir -p /tmp/.X11-unix

echo "Starting Xvfb..."
# Giảm RAM: hạ resolution + depth 16-bit
Xvfb ${DISPLAY} -screen 0 1024x576x16 -nolisten tcp -ac &
sleep 1

echo "Starting window manager (fluxbox)..."
fluxbox &

echo "Starting VNC server..."
x11vnc -display ${DISPLAY} -forever -shared -rfbport ${VNC_PORT} -nopw -noxrecord -noxfixes -noxdamage &

echo "Starting noVNC on 0.0.0.0:${PORT} -> localhost:${VNC_PORT}"
websockify --web=/usr/share/novnc 0.0.0.0:${PORT} localhost:${VNC_PORT} &

echo "Starting Firefox ESR..."
# Flags gọn nhẹ:
# - --no-remote/--new-instance: chạy độc lập trong container
# - --private-window: giảm sync/telemetry UI rườm rà
while true; do
  firefox-esr \
    --no-remote \
    --new-instance \
    --private-window \
    about:blank || true
  sleep 1
done
EOF

RUN chmod +x /usr/local/bin/start-gui.sh
CMD ["/usr/local/bin/start-gui.sh"]
