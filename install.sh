#!/bin/bash
# Mymusicom Player - Installation / Desinstallation pour Raspberry Pi
#
# Installer :    curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash
# Desinstaller : curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --uninstall

REPO="barryab12/mymusicom-releases"
DEB_NAME="mymusicom-server.deb"

# ──────────────────────────────────────────────
#  DESINSTALLATION
# ──────────────────────────────────────────────
if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
  echo ""
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║     MYMUSICOM PLAYER UNINSTALLER     ║"
  echo "  ╚══════════════════════════════════════╝"
  echo ""

  echo "[1/5] Arret des services..."
  sudo systemctl stop mymusicom-server@* mymusicom-kiosk@* 2>/dev/null || true
  sudo systemctl disable mymusicom-server@* mymusicom-kiosk@* 2>/dev/null || true
  echo "  Services arretes"

  echo "[2/5] Arret des processus..."
  pkill -f ffplay 2>/dev/null || true
  pkill -f "node.*server.js" 2>/dev/null || true
  pkill -f chromium-browser 2>/dev/null || true
  echo "  Processus arretes"

  echo "[3/5] Desinstallation des packages..."
  # Remove postrm first to avoid SSH drops from kill commands in postremove
  sudo rm -f /var/lib/dpkg/info/mymusicom-server.postrm 2>/dev/null || true
  sudo rm -f /var/lib/dpkg/info/mymusicom-desktop.postrm 2>/dev/null || true
  sudo dpkg --purge --force-all mymusicom-server 2>/dev/null || true
  sudo dpkg --purge --force-all mymusicom-desktop 2>/dev/null || true
  echo "  Packages supprimes"

  echo "[4/5] Suppression des fichiers..."
  sudo rm -rf /opt/mymusicom-server
  sudo rm -rf "/opt/Mymusicom App"
  sudo rm -f /etc/systemd/system/mymusicom-*.service
  sudo rm -f /usr/share/applications/mymusicom*.desktop
  sudo rm -f /usr/share/pixmaps/mymusicom*.png
  rm -f ~/Desktop/mymusicom*.desktop 2>/dev/null || true
  rm -f ~/Bureau/mymusicom*.desktop 2>/dev/null || true
  rm -f ~/.config/autostart/mymusicom-*.desktop 2>/dev/null || true
  rm -rf ~/.mymusicom
  rm -rf ~/.config/chromium/Default/Service\ Worker
  rm -rf ~/.cache/chromium
  echo "  Fichiers supprimes"

  echo "[5/5] Rechargement systemd..."
  sudo systemctl daemon-reload
  sudo update-desktop-database /usr/share/applications 2>/dev/null || true
  echo "  Systemd recharge"

  echo ""
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║    DESINSTALLATION TERMINEE !        ║"
  echo "  ╚══════════════════════════════════════╝"
  echo ""
  echo "  Tout a ete supprime :"
  echo "    - Packages mymusicom-server et mymusicom-desktop"
  echo "    - Dossiers /opt/mymusicom-server et /opt/Mymusicom App"
  echo "    - Services systemd"
  echo "    - Icone du bureau et du menu"
  echo "    - Donnees utilisateur (~/.mymusicom/)"
  echo "    - Cache Chromium"
  echo ""
  exit 0
fi

# ──────────────────────────────────────────────
#  INSTALLATION
# ──────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║       MYMUSICOM PLAYER INSTALLER     ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# Detect user for systemd services
SERVICE_USER=$(whoami)
if [ "$SERVICE_USER" = "root" ]; then
  # Running as root via sudo, find the real user
  SERVICE_USER=$(logname 2>/dev/null || echo "pi")
fi
echo "  Utilisateur: $SERVICE_USER"

# Check architecture
ARCH=$(dpkg --print-architecture 2>/dev/null)
echo "  Architecture: $ARCH"
if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "armhf" ]; then
  echo ""
  echo "  ERREUR: Ce package est pour Raspberry Pi (arm64/armhf)."
  exit 1
fi

# Check prerequisites
echo ""
echo "[0/4] Verification des prerequis..."

# Node.js 18+
NODE_OK=0
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node -v | cut -d. -f1 | tr -d v)
  if [ "$NODE_VER" -ge 18 ] 2>/dev/null; then
    NODE_OK=1
    echo "  nodejs $(node -v) OK"
  else
    echo "  nodejs $(node -v) trop ancien, mise a jour..."
  fi
else
  echo "  nodejs manquant, installation..."
fi

if [ "$NODE_OK" = "0" ]; then
  echo "  Installation de Node.js 18..."
  curl -fsSL https://deb.nodesource.com/setup_18.x 2>/dev/null | sudo -E bash - >/dev/null 2>&1
  if ! sudo apt-get install -y nodejs 2>&1 | tail -3; then
    echo "  ERREUR: Impossible d'installer Node.js 18"
    echo "  Essayez manuellement: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
    exit 1
  fi
  echo "  nodejs $(node -v) installe"
fi

# ffmpeg
if ! command -v ffplay >/dev/null 2>&1; then
  echo "  Installation de ffmpeg..."
  sudo apt-get install -y ffmpeg 2>&1 | tail -1
fi

# chromium
if ! command -v chromium-browser >/dev/null 2>&1; then
  echo "  Installation de chromium-browser..."
  sudo apt-get install -y chromium-browser 2>&1 | tail -1
fi

echo "  Prerequis OK"

# Get latest release download URL
echo ""
echo "[1/4] Recherche de la derniere version..."
API_RESPONSE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep "browser_download_url.*\.deb" | head -1 | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "  ERREUR: Impossible de trouver le .deb sur GitHub."
  echo "  Reponse API: $(echo "$API_RESPONSE" | head -5)"
  echo "  Verifiez: https://github.com/$REPO/releases"
  exit 1
fi

VERSION=$(echo "$DOWNLOAD_URL" | grep -oP '_\K[0-9]+\.[0-9]+\.[0-9]+' || echo "latest")
echo "  Version: $VERSION"
echo "  URL: $DOWNLOAD_URL"

# Download
echo ""
echo "[2/4] Telechargement..."
if ! curl -L -o "/tmp/$DEB_NAME" "$DOWNLOAD_URL" --progress-bar; then
  echo "  ERREUR: Echec du telechargement"
  exit 1
fi
DEB_SIZE=$(du -h "/tmp/$DEB_NAME" | cut -f1)
echo "  Telecharge: $DEB_SIZE"

# Uninstall previous versions
echo ""
echo "[3/4] Nettoyage des anciennes versions..."
sudo systemctl stop "mymusicom-server@${SERVICE_USER}" "mymusicom-kiosk@${SERVICE_USER}" 2>/dev/null || true
sudo systemctl stop mymusicom-server@pi mymusicom-kiosk@pi 2>/dev/null || true
# Remove postrm to avoid SSH drops
sudo rm -f /var/lib/dpkg/info/mymusicom-server.postrm 2>/dev/null || true
sudo rm -f /var/lib/dpkg/info/mymusicom-desktop.postrm 2>/dev/null || true
sudo dpkg --purge --force-all mymusicom-desktop 2>/dev/null || true
sudo dpkg --purge --force-all mymusicom-server 2>/dev/null || true
sudo rm -rf "/opt/Mymusicom App" /opt/mymusicom-server 2>/dev/null || true
sudo rm -f /etc/systemd/system/mymusicom-*.service 2>/dev/null || true
rm -f ~/.config/autostart/mymusicom-*.desktop 2>/dev/null || true
pkill -f chromium-browser 2>/dev/null || true
pkill -f ffplay 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true
echo "  Nettoyage termine"

# Install
echo ""
echo "[4/4] Installation..."
if ! sudo dpkg -i "/tmp/$DEB_NAME"; then
  echo "  Resolution des dependances..."
  sudo apt-get install -f -y 2>&1 | tail -3
fi
rm -f "/tmp/$DEB_NAME"

# Verify installation
echo ""
echo "  Verification..."
sleep 5

SERVER_STATUS=$(systemctl is-active "mymusicom-server@${SERVICE_USER}" 2>/dev/null || systemctl is-active mymusicom-server@pi 2>/dev/null || echo "inactive")
KIOSK_STATUS=$(systemctl is-active "mymusicom-kiosk@${SERVICE_USER}" 2>/dev/null || systemctl is-active mymusicom-kiosk@pi 2>/dev/null || echo "inactive")

# If services didn't start automatically, try to start them
if [ "$SERVER_STATUS" != "active" ]; then
  echo "  Demarrage du serveur..."
  sudo systemctl enable "mymusicom-server@${SERVICE_USER}" 2>/dev/null || true
  sudo systemctl start "mymusicom-server@${SERVICE_USER}" 2>/dev/null || true
  sleep 5
  SERVER_STATUS=$(systemctl is-active "mymusicom-server@${SERVICE_USER}" 2>/dev/null || echo "inactive")
fi

if [ "$KIOSK_STATUS" != "active" ]; then
  echo "  Demarrage du kiosk..."
  sudo systemctl enable "mymusicom-kiosk@${SERVICE_USER}" 2>/dev/null || true
  sudo systemctl start "mymusicom-kiosk@${SERVICE_USER}" 2>/dev/null || true
  sleep 3
  KIOSK_STATUS=$(systemctl is-active "mymusicom-kiosk@${SERVICE_USER}" 2>/dev/null || echo "inactive")
fi

# Check if server is responding
PORT_OK="non"
if curl -s -o /dev/null -w '%{http_code}' http://localhost:3009/ 2>/dev/null | grep -qE '200|302'; then
  PORT_OK="oui"
fi

echo ""
echo "  ╔══════════════════════════════════════╗"
if [ "$SERVER_STATUS" = "active" ] && [ "$PORT_OK" = "oui" ]; then
  echo "  ║       INSTALLATION TERMINEE !        ║"
else
  echo "  ║    INSTALLATION AVEC AVERTISSEMENTS  ║"
fi
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  Serveur:  $SERVER_STATUS  (systemctl status mymusicom-server@${SERVICE_USER})"
echo "  Kiosk:    $KIOSK_STATUS  (systemctl status mymusicom-kiosk@${SERVICE_USER})"
echo "  Port 3009: $PORT_OK"

if [ "$SERVER_STATUS" != "active" ]; then
  echo ""
  echo "  PROBLEME: Le serveur n'a pas demarre."
  echo "  Diagnostic:"
  journalctl -u "mymusicom-server@${SERVICE_USER}" --no-pager -n 10 2>&1
  echo ""
  echo "  Essayez: sudo systemctl restart mymusicom-server@${SERVICE_USER}"
fi

IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -n "$IP_ADDR" ] && [ "$PORT_OK" = "oui" ]; then
  echo ""
  echo "  Web: http://${IP_ADDR}:3009"
fi

echo ""
echo "  Pour desinstaller :"
echo "  curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --uninstall"
echo ""
