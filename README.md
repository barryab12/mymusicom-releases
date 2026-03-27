# Mymusicom Player

Lecteur musical professionnel pour Raspberry Pi.

## Installation

```bash
curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash
```

## Mise a jour

```bash
# Derniere version
curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --update

# Version specifique
curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --version=1.0.21
```

## Desinstallation

```bash
curl -sL https://raw.githubusercontent.com/barryab12/mymusicom-releases/main/install.sh | bash -s -- --uninstall
```

## Versions

| Version | Date | Notes |
|---------|------|-------|
| 1.0.22 | 2026-03-27 | Fix barre de progression UI |
| 1.0.21 | 2026-03-27 | Fix lecture manuelle, bouton Programme auto, icones SVG |
| 1.0.20 | 2026-03-27 | Fix mutex resume-program |
| 1.0.19 | 2026-03-27 | Fix mutex deadlock lecture manuelle |
| 1.0.18 | 2026-03-27 | Refactor endpoint play-playlist |
| 1.0.17 | 2026-03-21 | Fix crossfade race condition |
| 1.0.16 | 2026-03-20 | Fix sync after reboot on WiFi |
| 1.0.15 | 2026-03-19 | Optimize chromium kiosk flags for RPi |
