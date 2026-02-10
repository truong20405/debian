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
# Base packages
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

RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html || true

# Profile dir (giữ phiên)
RUN mkdir -p /data/firefox && chmod -R 777 /data

# -------------------------------
# Entrypoint
# -------------------------------
RUN cat > /usr/local/bin/start-gui.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Timezone: ${TZ}"
echo "Railway PORT: ${PORT}"
echo "DISPLAY: ${DISPLAY}"

mkdir -p /run/dbus
dbus-daemon --system --fork || true

rm -f /tmp/.X99-lock || true
rm -rf /tmp/.X11-unix/X99 || true
mkdir -p /tmp/.X11-unix

echo "Starting Xvfb..."
Xvfb ${DISPLAY} -screen 0 1024x576x16 -nolisten tcp -ac &
sleep 1

echo "Starting window manager (fluxbox)..."
fluxbox &

echo "Starting VNC server..."
x11vnc -display ${DISPLAY} -forever -shared -rfbport ${VNC_PORT} -nopw -noxrecord -noxfixes -noxdamage &

echo "Starting noVNC on 0.0.0.0:${PORT} -> localhost:${VNC_PORT}"
websockify --web=/usr/share/novnc 0.0.0.0:${PORT} localhost:${VNC_PORT} &

# --- Firefox profile cố định để giữ session ---
PROFILE_DIR="/data/firefox/profile"
mkdir -p "${PROFILE_DIR}"

# Tạo profile nếu chưa có (lần đầu)
if [ ! -f "${PROFILE_DIR}/times.json" ] && [ ! -f "${PROFILE_DIR}/prefs.js" ]; then
  echo "Creating Firefox profile at ${PROFILE_DIR}..."
  # firefox-esr cần DISPLAY đang chạy
  firefox-esr --headless -CreateProfile "default ${PROFILE_DIR}" || true
fi

echo "Starting Firefox ESR with persistent profile..."
# KHÔNG private -> giữ cookie/session
# --no-remote/--new-instance: chạy độc lập
# -profile: ép dùng đúng profile thư mục
while true; do
  firefox-esr \
    --no-remote \
    --new-instance \
    -profile "${PROFILE_DIR}" \
    about:blank || true
  sleep 1
done
EOF

RUN chmod +x /usr/local/bin/start-gui.sh
CMD ["/usr/local/bin/start-gui.sh"]
