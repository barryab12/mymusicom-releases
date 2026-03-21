#!/bin/bash
# Mymusicom Player - Installation / Desinstallation pour Raspberry Pi
#
# Installer :    curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash
# Desinstaller : curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --uninstall
set -e

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
  sudo dpkg --purge --force-all mymusicom-server 2>/dev/null || true
  sudo dpkg --purge --force-all mymusicom-desktop 2>/dev/null || true
  echo "  Packages supprimes"

  echo "[4/5] Suppression des fichiers..."
  # Installation
  sudo rm -rf /opt/mymusicom-server
  sudo rm -rf "/opt/Mymusicom App"
  # Services systemd
  sudo rm -f /etc/systemd/system/mymusicom-*.service
  # Desktop et icones
  sudo rm -f /usr/share/applications/mymusicom*.desktop
  sudo rm -f /usr/share/pixmaps/mymusicom*.png
  rm -f ~/Desktop/mymusicom*.desktop 2>/dev/null || true
  rm -f ~/Bureau/mymusicom*.desktop 2>/dev/null || true
  # Autostart
  rm -f ~/.config/autostart/mymusicom-*.desktop 2>/dev/null || true
  # Donnees utilisateur (config, playlists, cache, logs)
  rm -rf ~/.mymusicom
  # Cache Chromium (Service Workers + cache)
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

# Check architecture
ARCH=$(dpkg --print-architecture 2>/dev/null)
if [ "$ARCH" != "arm64" ]; then
  echo "ERREUR: Ce package est pour Raspberry Pi (arm64)."
  echo "Architecture detectee: $ARCH"
  exit 1
fi

# Check prerequisites
echo "[0/4] Verification des prerequis..."
MISSING=""
command -v node >/dev/null 2>&1 || MISSING="nodejs"
command -v ffplay >/dev/null 2>&1 || MISSING="$MISSING ffmpeg"
command -v chromium-browser >/dev/null 2>&1 || MISSING="$MISSING chromium-browser"

if [ -n "$MISSING" ]; then
  echo "  Installation des packages manquants:$MISSING"
  if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 18 ] 2>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - >/dev/null 2>&1
  fi
  sudo apt-get install -y $MISSING >/dev/null 2>&1
  echo "  Prerequis installes"
fi

# Get latest release download URL
echo "[1/4] Recherche de la derniere version..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep "browser_download_url.*\.deb" | head -1 | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "ERREUR: Impossible de trouver le .deb."
  echo "Verifiez: https://github.com/$REPO/releases"
  exit 1
fi

VERSION=$(echo "$DOWNLOAD_URL" | grep -oP '_\K[0-9]+\.[0-9]+\.[0-9]+' || echo "latest")
echo "  Version: $VERSION"

# Download
echo "[2/4] Telechargement..."
curl -L -o "/tmp/$DEB_NAME" "$DOWNLOAD_URL" --progress-bar
DEB_SIZE=$(du -h "/tmp/$DEB_NAME" | cut -f1)
echo "  Telecharge: $DEB_SIZE"

# Uninstall previous versions
echo "[3/4] Nettoyage des anciennes versions..."
sudo systemctl stop mymusicom-server@* mymusicom-kiosk@* 2>/dev/null || true
sudo dpkg --purge --force-all mymusicom-desktop 2>/dev/null || true
sudo dpkg --purge --force-all mymusicom-server 2>/dev/null || true
sudo rm -rf "/opt/Mymusicom App" /opt/mymusicom-server 2>/dev/null || true
sudo rm -f /etc/systemd/system/mymusicom-*.service 2>/dev/null || true
rm -f ~/.config/autostart/mymusicom-*.desktop 2>/dev/null || true
pkill -f chromium-browser 2>/dev/null || true
pkill -f "node.*server.js" 2>/dev/null || true
pkill -f ffplay 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true
echo "  Nettoyage termine"

# Install
echo "[4/4] Installation..."
sudo dpkg -i "/tmp/$DEB_NAME" 2>&1
sudo apt-get install -f -y 2>&1 | tail -3
rm -f "/tmp/$DEB_NAME"

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║       INSTALLATION TERMINEE !        ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  Serveur: systemctl status mymusicom-server@pi"
echo "  Kiosk:   systemctl status mymusicom-kiosk@pi"
echo "  Logs:    journalctl -u mymusicom-server@pi -f"
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -n "$IP_ADDR" ]; then
  echo "  Web:     http://${IP_ADDR}:3009"
fi
echo ""
echo "  Pour desinstaller :"
echo "  curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --uninstall"
echo ""
