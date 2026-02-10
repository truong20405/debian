FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Ho_Chi_Minh
ENV PORT=8080

ENV DISPLAY=:99
ENV VNC_PORT=5900

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl tzdata \
    xvfb fluxbox x11vnc \
    dbus-x11 xauth x11-xserver-utils \
    fonts-dejavu \
    novnc websockify \
    gnupg \
    && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata

# --- Install Google Chrome Stable ---
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /usr/share/keyrings/google-linux-signing-keyring.gpg \
 && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-signing-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list \
 && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html || true

# data dir để giữ session + extensions
RUN mkdir -p /data/chrome && chmod -R 777 /data

RUN cat > /usr/local/bin/start-gui.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Timezone: ${TZ}"
echo "PORT: ${PORT}"
echo "DISPLAY: ${DISPLAY}"

rm -f /tmp/.X99-lock || true
rm -rf /tmp/.X11-unix/X99 || true
mkdir -p /tmp/.X11-unix

echo "Starting Xvfb..."
Xvfb ${DISPLAY} -screen 0 1024x576x16 -nolisten tcp -ac &
sleep 1

echo "Starting fluxbox..."
fluxbox &

echo "Starting x11vnc..."
x11vnc -display ${DISPLAY} -forever -shared -rfbport ${VNC_PORT} -nopw -noxrecord -noxfixes -noxdamage &

echo "Starting noVNC..."
websockify --web=/usr/share/novnc 0.0.0.0:${PORT} localhost:${VNC_PORT} &

echo "Starting Google Chrome (persistent profile)..."
USER_DATA_DIR="/data/chrome"
mkdir -p "${USER_DATA_DIR}"

while true; do
  google-chrome-stable \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --user-data-dir="${USER_DATA_DIR}" \
    --no-first-run \
    --disable-features=Translate,BackForwardCache,PreloadMediaEngagementData,MediaRouter \
    about:blank || true
  sleep 1
done
EOF

RUN chmod +x /usr/local/bin/start-gui.sh
CMD ["/usr/local/bin/start-gui.sh"]
