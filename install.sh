#!/bin/bash
# Mymusicom Player - Installation / Mise a jour / Desinstallation pour Raspberry Pi
#
# Installer :                curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash
# Mettre a jour :            curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --update
# Installer version precise: curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --version=1.0.21
# Desinstaller :             curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --uninstall

REPO="barryab12/mymusicom-releases"
DEB_NAME="mymusicom-server.deb"
MODE="install"
TARGET_VERSION=""

for arg in "$@"; do
  case "$arg" in
    --uninstall|-u)
      MODE="uninstall"
      ;;
    --update|-up)
      MODE="update"
      ;;
    --version=*)
      TARGET_VERSION="${arg#--version=}"
      MODE="update"
      ;;
  esac
done

# ──────────────────────────────────────────────
#  DESINSTALLATION
# ──────────────────────────────────────────────
if [ "$MODE" = "uninstall" ]; then
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
  pkill -f chromium 2>/dev/null || true
  echo "  Processus arretes"

  echo "[3/5] Desinstallation des packages..."
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
#  INSTALLATION / MISE A JOUR
# ──────────────────────────────────────────────

if [ "$MODE" = "update" ]; then
  TITLE="MYMUSICOM PLAYER UPDATER"
else
  TITLE="MYMUSICOM PLAYER INSTALLER"
fi

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║       $TITLE     ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# Detect user for systemd services
SERVICE_USER=$(whoami)
if [ "$SERVICE_USER" = "root" ]; then
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

# Show current version if updating
if [ "$MODE" = "update" ]; then
  CURRENT_VER=$(dpkg -s mymusicom-server 2>/dev/null | grep "^Version:" | awk '{print $2}')
  if [ -n "$CURRENT_VER" ]; then
    echo "  Version actuelle: $CURRENT_VER"
  else
    echo "  Aucune version installee, basculement en mode installation"
    MODE="install"
  fi
fi

# Check prerequisites
echo ""
echo "[0/4] Verification des prerequis..."

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
    echo "  Essayez: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
    exit 1
  fi
  echo "  nodejs $(node -v) installe"
fi

if ! command -v ffplay >/dev/null 2>&1; then
  echo "  Installation de ffmpeg..."
  sudo apt-get install -y ffmpeg 2>&1 | tail -1
fi

if ! command -v chromium-browser >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
  echo "  Installation de chromium..."
  if apt-cache show chromium-browser >/dev/null 2>&1; then
    sudo apt-get install -y chromium-browser 2>&1 | tail -1
  else
    sudo apt-get install -y chromium 2>&1 | tail -1
  fi
fi

if ! command -v aplay >/dev/null 2>&1; then
  echo "  Installation de alsa-utils..."
  sudo apt-get install -y alsa-utils 2>&1 | tail -1
fi

if ! command -v pulseaudio >/dev/null 2>&1; then
  echo "  Installation de pulseaudio..."
  sudo apt-get install -y pulseaudio 2>&1 | tail -1
fi

# Ajouter l'utilisateur au groupe audio
if ! groups "$SERVICE_USER" 2>/dev/null | grep -qw audio; then
  echo "  Ajout de $SERVICE_USER au groupe audio..."
  sudo usermod -aG audio "$SERVICE_USER"
fi

echo "  Prerequis OK"

# Get release (latest or specific version)
echo ""
if [ -n "$TARGET_VERSION" ]; then
  echo "[1/4] Recherche de la version v${TARGET_VERSION}..."
  # Remove leading 'v' if present
  TARGET_VERSION=$(echo "$TARGET_VERSION" | sed 's/^v//')
  API_RESPONSE=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/v${TARGET_VERSION}")
  DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep "browser_download_url.*\.deb" | head -1 | cut -d '"' -f 4)

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "  ERREUR: Version v${TARGET_VERSION} introuvable."
    echo "  Versions disponibles :"
    curl -s "https://api.github.com/repos/$REPO/releases" | grep '"tag_name"' | head -10 | sed 's/.*"tag_name": *"//;s/".*//' | while read -r tag; do echo "    - $tag"; done
    exit 1
  fi
else
  echo "[1/4] Recherche de la derniere version..."
  API_RESPONSE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
  DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep "browser_download_url.*\.deb" | head -1 | cut -d '"' -f 4)

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "  ERREUR: Impossible de trouver le .deb sur GitHub."
    echo "  Reponse API: $(echo "$API_RESPONSE" | head -5)"
    echo "  Verifiez: https://github.com/$REPO/releases"
    exit 1
  fi
fi

NEW_VER=$(echo "$DOWNLOAD_URL" | grep -oP '_\K[0-9]+\.[0-9]+\.[0-9]+' || echo "latest")
echo "  Version disponible: $NEW_VER"

# Skip if already up to date (update mode only, not when specific version requested)
if [ "$MODE" = "update" ] && [ -z "$TARGET_VERSION" ] && [ "$CURRENT_VER" = "$NEW_VER" ]; then
  echo ""
  echo "  Deja a jour (v${CURRENT_VER}). Rien a faire."
  echo ""
  exit 0
fi

# Download
echo ""
echo "[2/4] Telechargement..."
if ! curl -L -o "/tmp/$DEB_NAME" "$DOWNLOAD_URL" --progress-bar; then
  echo "  ERREUR: Echec du telechargement"
  exit 1
fi
DEB_SIZE=$(du -h "/tmp/$DEB_NAME" | cut -f1)
echo "  Telecharge: $DEB_SIZE"

# Remove previous installation
echo ""
if [ "$MODE" = "update" ]; then
  echo "[3/4] Mise a jour (donnees conservees)..."
else
  echo "[3/4] Nettoyage des anciennes versions..."
fi

sudo systemctl stop "mymusicom-server@${SERVICE_USER}" "mymusicom-kiosk@${SERVICE_USER}" 2>/dev/null || true
sudo systemctl stop mymusicom-server@pi mymusicom-kiosk@pi 2>/dev/null || true
pkill -f ffplay 2>/dev/null || true
pkill -f chromium-browser 2>/dev/null || true
pkill -f chromium 2>/dev/null || true
sudo rm -f /var/lib/dpkg/info/mymusicom-server.postrm 2>/dev/null || true
sudo rm -f /var/lib/dpkg/info/mymusicom-desktop.postrm 2>/dev/null || true
sudo dpkg --purge --force-all mymusicom-desktop 2>/dev/null || true
sudo dpkg --purge --force-all mymusicom-server 2>/dev/null || true
sudo rm -rf "/opt/Mymusicom App" /opt/mymusicom-server 2>/dev/null || true
sudo rm -f /etc/systemd/system/mymusicom-*.service 2>/dev/null || true
rm -f ~/.config/autostart/mymusicom-*.desktop 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true

if [ "$MODE" = "update" ]; then
  echo "  Ancienne version supprimee (donnees ~/.mymusicom/ conservees)"
else
  echo "  Nettoyage termine"
fi

# Install
echo ""
echo "[4/4] Installation v${NEW_VER}..."
if ! sudo dpkg -i "/tmp/$DEB_NAME"; then
  echo "  Resolution des dependances..."
  sudo apt-get install -f -y 2>&1 | tail -3
fi
rm -f "/tmp/$DEB_NAME"

# Verify
echo ""
echo "  Verification..."
sleep 5

SERVER_STATUS=$(systemctl is-active "mymusicom-server@${SERVICE_USER}" 2>/dev/null || systemctl is-active mymusicom-server@pi 2>/dev/null || echo "inactive")
KIOSK_STATUS=$(systemctl is-active "mymusicom-kiosk@${SERVICE_USER}" 2>/dev/null || systemctl is-active mymusicom-kiosk@pi 2>/dev/null || echo "inactive")

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

PORT_OK="non"
if curl -s -o /dev/null -w '%{http_code}' http://localhost:3009/ 2>/dev/null | grep -qE '200|302'; then
  PORT_OK="oui"
fi

echo ""
echo "  ╔══════════════════════════════════════╗"
if [ "$SERVER_STATUS" = "active" ] && [ "$PORT_OK" = "oui" ]; then
  if [ "$MODE" = "update" ]; then
    echo "  ║       MISE A JOUR TERMINEE !         ║"
  else
    echo "  ║       INSTALLATION TERMINEE !        ║"
  fi
else
  echo "  ║    INSTALLATION AVEC AVERTISSEMENTS  ║"
fi
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  Version:    $NEW_VER"
echo "  Serveur:    $SERVER_STATUS"
echo "  Kiosk:      $KIOSK_STATUS"
echo "  Port 3009:  $PORT_OK"

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
  echo "  Web:        http://${IP_ADDR}:3009"
fi

echo ""
echo "  Commandes disponibles :"
echo "  Mettre a jour :         curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --update"
echo "  Version specifique :    curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --version=X.Y.Z"
echo "  Desinstaller :          curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --uninstall"
echo ""
